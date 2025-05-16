// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "../interfaces/IERC20.sol";
import {IPool} from "../interfaces/aave/IPool.sol";
import {IAaveOracle} from "../interfaces/aave/IAaveOracle.sol";
import {IPoolDataProvider} from "../interfaces/aave/IPoolDataProvider.sol";
import {
    AAVE_POOL, AAVE_ORACLE, AAVE_POOL_DATA_PROVIDER
} from "./Constants.sol";

/// @title AaveHelper
/// @notice Provides utility functions for interacting with the Aave protocol.
/// @dev This contract is abstract and can be extended to include custom functionality.
abstract contract AaveHelper {
    IPool internal constant pool = IPool(AAVE_POOL);
    IPoolDataProvider internal constant dataProvider =
        IPoolDataProvider(AAVE_POOL_DATA_PROVIDER);
    IAaveOracle internal constant oracle = IAaveOracle(AAVE_ORACLE);

    /// @notice Supplies tokens to the Aave protocol.
    /// @param token The address of the ERC20 token to supply.
    /// @param amount The amount of tokens to supply.
    function supply(address token, uint256 amount) public {
        pool.supply({
            asset: token,
            amount: amount,
            onBehalfOf: address(this),
            referralCode: 0
        });
    }

    /// @notice Borrows tokens from the Aave protocol.
    /// @param token The address of the ERC20 token to borrow.
    /// @param amount The amount of tokens to borrow.
    function borrow(address token, uint256 amount) public {
        pool.borrow({
            asset: token,
            amount: amount,
            interestRateMode: 2, // Variable rate
            referralCode: 0,
            onBehalfOf: address(this)
        });
    }

    /// @notice Repays borrowed tokens to the Aave protocol.
    /// @param token The address of the ERC20 token to repay.
    /// @param amount The amount of tokens to repay. Use `type(uint256).max` to repay all.
    /// @return repaid The actual amount repaid.
    function repay(address token, uint256 amount)
        public
        returns (uint256 repaid)
    {
        return pool.repay({
            asset: token,
            amount: amount,
            interestRateMode: 2, // Variable rate
            onBehalfOf: address(this)
        });
    }

    /// @notice Withdraws supplied tokens from the Aave protocol.
    /// @param token The address of the ERC20 token to withdraw.
    /// @param amount The amount of tokens to withdraw. Use `type(uint256).max` to withdraw all.
    /// @return withdrawn The actual amount withdrawn.
    function withdraw(address token, uint256 amount)
        public
        returns (uint256 withdrawn)
    {
        return pool.withdraw({asset: token, amount: amount, to: address(this)});
    }

    /// @notice Executes a flash loan using the Aave protocol.
    /// @param token The address of the ERC20 token to borrow.
    /// @param amount The amount of tokens to borrow.
    /// @param data Arbitrary data to pass to the `_flashLoanCallback` function.
    function flashLoan(address token, uint256 amount, bytes memory data)
        public
    {
        pool.flashLoanSimple({
            receiverAddress: address(this),
            asset: token,
            amount: amount,
            params: data,
            referralCode: 0
        });
    }

    /// @notice Callback function for handling flash loan operations.
    /// @param token The address of the ERC20 token involved in the flash loan.
    /// @param amount The amount of tokens borrowed.
    /// @param fee The flash loan fee.
    /// @param initiator The address that initiated the flash loan.
    /// @param params Arbitrary data passed from the `flashLoan` function.
    /// @return A boolean indicating success.
    /// @dev Ensures the sender is the Aave pool and the initiator is this contract.
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        require(msg.sender == address(pool), "not authorized");
        require(initiator == address(this), "invalid initiator");

        _flashLoanCallback(token, amount, fee, params);

        return true;
    }

    /// @notice Abstract function to handle flash loan callback logic.
    /// @param token The address of the ERC20 token involved in the flash loan.
    /// @param amount The amount of tokens borrowed.
    /// @param fee The flash loan fee.
    /// @param params Arbitrary data passed from the `flashLoan` function.
    function _flashLoanCallback(
        address token,
        uint256 amount,
        uint256 fee,
        bytes memory params
    ) internal virtual;

    /// @notice Retrieves the variable debt of a user for a specific token.
    /// @param user The address of the user.
    /// @param token The address of the ERC20 token.
    /// @return The variable debt amount.
    function getDebt(address user, address token)
        public
        view
        returns (uint256)
    {
        IPool.ReserveData memory reserve = pool.getReserveData(token);
        return IERC20(reserve.variableDebtTokenAddress).balanceOf(user);
    }

    /// @notice Retrieves the health factor of a user.
    /// @param user The address of the user.
    /// @return The user's health factor.
    function getHealthFactor(address user) public view returns (uint256) {
        (
            , // uint256 totalCollateralBase
            , // uint256 totalDebtBase
            , // uint256 availableBorrowsBase
            , // uint256 currentLiquidationThreshold
            , // uint256 ltv
            uint256 healthFactor
        ) = pool.getUserAccountData(user);

        return healthFactor;
    }
}
