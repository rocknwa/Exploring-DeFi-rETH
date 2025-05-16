// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./interfaces/IERC20.sol";
import {Pay} from "././helpers/Pay.sol";
import {Token} from "././helpers/Token.sol";
import {AaveHelper} from "././helpers/AaveHelper.sol";
import {SwapHelper} from "././helpers/SwapHelper.sol";

// Requirements
// - Delegatecall into this contract from Proxy
// - One Proxy contract per open position (coin / collateral pair)

/// @title FlashLev
/// @notice This contract allows for leveraged positions in Aave,
//          enabling users to open and close positions with flash loans.
/// @dev The contract interacts with Aave's flash loan, swap, and collateral management mechanisms.
contract FlashLev is Pay, Token, AaveHelper, SwapHelper {
    /*
    Definitions
    -----------
    HF = health factor
    LTV = ratio of loan to value of collateral

    Steps to open a position
    ------------------------
    1. Flash loan stable coin
    2. Swap stable coin to collateral <--- makes HF < target HF
    3. Supply swapped collateral + base collateral
    4. Borrow stable coin (flash loan amount + fee)
    5. Repay flash loan

    Steps to close a position
    -------------------------
    1. Flash loan stable coin
    2. Repay stable coin debt (open step 3)
    3. Withdraw collateral (open step 2)
    4. Swap collateral to stable coin
    5. Repay flash loan

    Math - find flash loan amount
    ------------------------
    total_borrow_usd / total_col_usd <= LTV

    total_borrow_usd = flash_loan_usd
                     = base_col_usd * k

    Assume swap_col_usd = flash_loan_usd (no slippage or fee on swap)

    total_col_usd = swap_col_usd + base_col_usd
                  = flash_loan_usd + base_col_usd
                  = base_col_usd * (k + 1)


    base_col_usd * k / (base_col_usd * (k + 1)) <= LTV
    k / (k + 1) <= LTV

    k <= LTV * (k + 1)
    k * (1 - LTV) <= LTV
    k <= LTV / (1 - LTV)

    flash_loan_usd = base_col_usd * k <= base_col_usd * LTV / (1 - LTV)
    */

    /// @notice Get the maximum flash loan amount for a given collateral type and base collateral amount
    /// @param collateral Address of the collateral asset
    /// @param baseColAmount The amount of collateral to use for the loan
    /// @return max The maximum flash loan amount (in USD with 18 decimals) that can be borrowed
    /// @return price The price of the collateral asset in USD (8 decimals)
    /// @return ltv The loan-to-value ratio for the collateral (4 decimals)
    /// @return maxLev The maximum leverage factor allowed for the collateral (4 decimals)
    /// @dev This function calculates the maximum loan amount and related values
    //       based on the collateral's price and LTV.
    function getMaxFlashLoanAmountUsd(address collateral, uint256 baseColAmount)
        external
        view
        returns (uint256 max, uint256 price, uint256 ltv, uint256 maxLev)
    {
         uint256 decimals;
        (decimals, ltv,,,,,,,,) =
            dataProvider.getReserveConfigurationData(collateral);

        // 1e8 = 1 USD
        price = oracle.getAssetPrice(collateral);

        // Normalize baseColAmount to 18 decimals
        // LTV 100% = 1e4
        max = baseColAmount * 10 ** (18 - decimals) * price * ltv / (1e4 - ltv)
            / 1e8;

        maxLev = ltv * 1e4 / (1e4 - ltv);

        return (max, price, ltv, maxLev);
    }

    /// @notice Parameters for the swap process
    /// @param amountOutMin Minimum amount of output token to receive
    /// @param data Additional swap data
    struct SwapParams {
        uint256 amountOutMin;
        bytes data;
    }

    /// @notice Data structure for flash loan operations
    /// @param coin Address of the coin being borrowed
    /// @param collateral Address of the collateral asset
    /// @param open Boolean indicating if the position is being opened or closed
    /// @param caller The address of the user calling the operation
    /// @param colAmount The amount of collateral supplied by caller for opening a position.
    //                   For closing, this is the amount of collateral to keep.
    /// @param swap Swap parameters for collateral to coin swap
    struct FlashLoanData {
        address coin;
        address collateral;
        bool open;
        address caller;
        uint256 colAmount;
        SwapParams swap;
    }

    /// @notice Parameters for opening a leveraged position
    /// @param coin Address of the coin being borrowed
    /// @param collateral Address of the collateral asset
    /// @param colAmount The amount of collateral to deposit
    /// @param coinAmount The amount of coin to borrow via the flash loan
    /// @param swap Swap parameters for collateral to coin swap
    /// @param minHealthFactor The minimum health factor required for the position
    struct OpenParams {
        address coin;
        address collateral;
        uint256 colAmount;
        uint256 coinAmount;
        SwapParams swap;
        uint256 minHealthFactor;
    }

    /// @notice Parameters for closing a leveraged position
    /// @param coin Address of the coin being borrowed
    /// @param collateral Address of the collateral asset
    /// @param colAmount The amount of collateral to keep after closing the position
    /// @param swap Swap parameters for coin to collateral swap
    struct CloseParams {
        address coin;
        address collateral;
        uint256 colAmount;
        SwapParams swap;
    }

    /// @notice Open a leveraged position using a flash loan
    /// @param params Parameters for opening the position including collateral and coin amounts,
    //                and minimum health factor
    function open(OpenParams calldata params) external {
         IERC20(params.collateral).transferFrom(
            msg.sender, address(this), params.colAmount
        );

        flashLoan({
            token: params.coin,
            amount: params.coinAmount,
            data: abi.encode(
                FlashLoanData({
                    coin: params.coin,
                    collateral: params.collateral,
                    open: true,
                    caller: msg.sender,
                    colAmount: params.colAmount,
                    swap: params.swap
                })
            )
        });

        require(
            getHealthFactor(address(this)) >= params.minHealthFactor, "hf < min"
        );
    }

    /// @notice Close a leveraged position by repaying the borrowed coin
    /// @param params Parameters for closing the position, including the amount of collateral to keep
    function close(CloseParams calldata params) external {
        uint256 coinAmount = getDebt(address(this), params.coin);
        flashLoan({
            token: params.coin,
            amount: coinAmount,
            data: abi.encode(
                FlashLoanData({
                    coin: params.coin,
                    collateral: params.collateral,
                    open: false,
                    caller: msg.sender,
                    colAmount: params.colAmount,
                    swap: params.swap
                })
            )
        });
    }

    /// @notice Callback function for handling flash loan operations
    /// @param token Address of the token used in the flash loan
    /// @param amount The amount of the token borrowed
    /// @param fee The fee for the flash loan
    /// @param params Parameters for the flash loan operation. Decode it into FlashLoanData.
    /// @dev This function is executed after the flash loan is issued.
    //       It handles the logic for opening or closing positions.
    function _flashLoanCallback(
        address token,
        uint256 amount,
        uint256 fee,
        bytes memory params
    ) internal override {
         uint256 repayAmount = amount + fee;

        FlashLoanData memory data = abi.decode(params, (FlashLoanData));
        IERC20 coin = IERC20(data.coin);
        IERC20 collateral = IERC20(data.collateral);

        if (data.open) {
            uint256 colAmountOut = swap({
                tokenIn: address(coin),
                tokenOut: address(collateral),
                amountIn: amount,
                amountOutMin: data.swap.amountOutMin,
                data: data.swap.data
            });

            uint256 colAmount = colAmountOut + data.colAmount;

            collateral.approve(address(pool), colAmount);
            supply(address(collateral), colAmount);

            borrow(address(coin), repayAmount);
        } else {
            coin.approve(address(pool), amount);
            repay(address(coin), amount);

            uint256 colWithdrawn =
                withdraw(address(collateral), type(uint256).max);
            uint256 colAmountIn = colWithdrawn - data.colAmount;

            collateral.transfer(data.caller, data.colAmount);

            uint256 coinAmountOut = swap({
                tokenIn: address(collateral),
                tokenOut: address(coin),
                amountIn: colAmountIn,
                amountOutMin: data.swap.amountOutMin,
                data: data.swap.data
            });

            if (coinAmountOut < repayAmount) {
                coin.transferFrom(
                    data.caller, address(this), repayAmount - coinAmountOut
                );
            } else {
                coin.transfer(data.caller, coinAmountOut - repayAmount);
            }
        }

        coin.approve(address(pool), repayAmount);
    }
}
