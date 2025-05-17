// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

// =================================================================================================
// Imports
// =================================================================================================

import {Test, console} from "forge-std/Test.sol"; // Foundry's standard library for testing, includes testing utilities and console logging.
import {IERC20} from "@src/interfaces/IERC20.sol"; // Standard ERC20 token interface.
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol"; // Interface for Rocket Pool's rETH token.
import {IPool} from "@src/interfaces/aave/IPool.sol"; // Interface for Aave's lending pool.
import {IAaveOracle} from "@src/interfaces/aave/IAaveOracle.sol"; // Interface for Aave's oracle.
import {IPoolDataProvider} from "@src/interfaces/aave/IPoolDataProvider.sol"; // Interface for Aave's pool data provider.
import {IVault} from "@src/interfaces/balancer/IVault.sol"; // Interface for Balancer's vault.
import {ISwapRouter} from "@src/interfaces/uniswap/ISwapRouter.sol"; // Interface for Uniswap's swap router.

// Import various constants (addresses, pool IDs, fees) used throughout the tests.
import {
    WETH, // Wrapped Ether address
    RETH, // Rocket Pool rETH address
    DAI, // DAI stablecoin address
    AAVE_POOL, // Aave V3 Pool address
    AAVE_ORACLE, // Aave Oracle address
    AAVE_POOL_DATA_PROVIDER, // Aave Pool Data Provider address
    BALANCER_VAULT, // Balancer Vault address
    BALANCER_POOL_RETH_WETH, // Balancer rETH/WETH pool address
    BALANCER_POOL_ID_RETH_WETH, // Balancer rETH/WETH pool ID
    UNISWAP_V3_SWAP_ROUTER_02, // Uniswap V3 SwapRouter02 address
    UNISWAP_V3_POOL_FEE_DAI_WETH // Uniswap V3 DAI/WETH pool fee tier
} from "@src/helpers/Constants.sol";
import {Proxy} from "@src/helpers/Proxy.sol"; // A simple proxy contract, likely used to execute calls on behalf of the test contract.
import {FlashLev} from "@src/FlashLev.sol"; // The main contract being tested, presumably for flash loan leveraging strategies.

// =================================================================================================
// Test Contract Definition
// =================================================================================================

// Command to run this specific test file using Foundry:
// forge test --fork-url $FORK_URL --evm-version cancun --match-path test/aave-flash-lev.sol -vvv

/**
 * @title FlashLevTest
 * @notice Test suite for the FlashLev contract, focusing on Aave interactions.
 * @dev This contract uses Foundry for testing. It requires a forked mainnet environment
 * (specified by $FORK_URL) and the Cancun EVM version to run correctly.
 * It tests flash loan leveraging operations involving Aave, Uniswap, and Balancer.
 */
contract FlashLevTest is Test {
    // =============================================================================================
    // State Variables
    // =============================================================================================

    IRETH constant internal reth = IRETH(RETH); // Constant instance of the IRETH token contract.
    IERC20 constant internal weth = IERC20(WETH); // Constant instance of the WETH token contract.
    IERC20 constant internal dai = IERC20(DAI); // Constant instance of the DAI token contract.
    IPool constant internal pool = IPool(AAVE_POOL); // Constant instance of the Aave V3 Pool contract.

    Proxy internal proxy; // Instance of the Proxy contract, used to make calls from a separate address.
    FlashLev internal flashLev; // Instance of the FlashLev contract (the contract under test).

    // =============================================================================================
    // Setup Function
    // =============================================================================================

    /**
     * @notice Sets up the test environment before each test case.
     * @dev This function is automatically called by Foundry before each test.
     * It deploys the FlashLev and Proxy contracts, deals initial token balances
     * to the test contract, approves the proxy for token spending, and labels
     * relevant addresses for easier debugging in Foundry's output.
     */
    function setUp() public {
        // Deploy the FlashLev contract.
        flashLev = new FlashLev();
        // Deploy the Proxy contract, making the test contract itself the owner/executor.
        proxy = new Proxy(address(this));

        // Deal 1 rETH to this test contract.
        deal(RETH, address(this), 1e18);
        // Deal 1000 DAI to this test contract.
        deal(DAI, address(this), 1000 * 1e18);

        // Approve the proxy contract to spend the maximum amount of rETH on behalf of this test contract.
        reth.approve(address(proxy), type(uint256).max);
        // Approve the proxy contract to spend the maximum amount of DAI on behalf of this test contract.
        dai.approve(address(proxy), type(uint256).max);

        // Label addresses for better readability in traces.
        vm.label(address(proxy), "Proxy");
        vm.label(address(flashLev), "FlashLev");
        vm.label(address(AAVE_POOL), "AavePoolV3"); // Changed from "Pool" for clarity
    }

    // =============================================================================================
    // Structs
    // =============================================================================================

    /**
     * @notice Struct to hold key Aave user account metrics.
     * @param hf Health Factor of the Aave position.
     * @param col Total collateral value in USD (base currency).
     * @param debt Total debt value in USD (base currency).
     * @param available Available borrowing power in USD (base currency).
     */
    struct Info {
        uint256 hf;
        uint256 col;
        uint256 debt;
        uint256 available;
    }

    // =============================================================================================
    // Helper Functions
    // =============================================================================================

    /**
     * @notice Retrieves and logs Aave user account data for a given user.
     * @param user The address of the user whose Aave account data is to be fetched.
     * @return info An Info struct containing the user's health factor, collateral, debt, and available borrows.
     * @dev All monetary values are typically in Aave's base currency (USD). Health Factor is scaled by 1e18.
     */
    function getInfo(address user) public view returns (Info memory) {
        (
            uint256 totalCollateralBase, // Total collateral in base currency (e.g., USD)
            uint256 totalDebtBase, // Total debt in base currency
            uint256 availableBorrowsBase, // Available borrowing power in base currency
            uint256 currentLiquidationThreshold, // Weighted average liquidation threshold
            uint256 ltv, // Weighted average loan-to-value ratio
            uint256 healthFactor // Health factor of the position
        ) = pool.getUserAccountData(user);

        // Log detailed Aave position metrics to the console.
        console.log("Aave User Collateral USD: %e", totalCollateralBase);
        console.log("Aave User Debt USD: %e", totalDebtBase);
        console.log("Aave User Available to borrow USD: %e", availableBorrowsBase);
        console.log("Aave User LTV (Loan-To-Value): %e", ltv); // Percentage scaled, e.g., 7500 for 75%
        console.log("Aave User Liquidation threshold: %e", currentLiquidationThreshold); // Percentage scaled
        console.log("Aave User Health factor: %e", healthFactor); // Scaled by 1e18

        return Info({
            hf: healthFactor,
            col: totalCollateralBase,
            debt: totalDebtBase,
            available: availableBorrowsBase
        });
    }

    // =============================================================================================
    // Test Functions
    // =============================================================================================

    /**
     * @notice Tests the `getMaxFlashLoanAmountUsd` function of the FlashLev contract.
     * @dev This function verifies that the calculated maximum flash loan amount, collateral price,
     * LTV, and maximum leverage are within expected ranges and greater than zero.
     */
    function test_getMaxFlashLoanAmountUsd() public view {
        uint256 colAmount = 1e18; // Define a sample collateral amount (1 rETH).

        // Call the function on the FlashLev contract to get flash loan parameters.
        (uint256 max, uint256 price, uint256 ltv, uint256 maxLev) =
            flashLev.getMaxFlashLoanAmountUsd(RETH, colAmount);

        // Log the retrieved values.
        console.log("Max flash loan USD: %e", max); // Maximum amount that can be flash loaned in USD.
        console.log("Collateral price (USD per asset, scaled by 1e8): %e", price); // Price of collateral (RETH) in USD, scaled.
        console.log("LTV (Loan-To-Value from Aave, scaled by 1e4, e.g. 7500 for 75%): %e", ltv); // LTV for RETH on Aave.
        console.log("Max leverage (scaled by 1e18): %e", maxLev); // Calculated maximum leverage possible.

        // Assertions to validate the results.
        assertGt(price, 0, "Collateral price must be greater than zero.");
        // Max flash loan amount should be at least the collateral value (colAmount * price / 1e8 to adjust for price scaling).
        assertGe(max, colAmount * price / 1e8, "Max flash loan amount seems too low.");
        assertGt(ltv, 0, "LTV must be greater than zero.");
        assertLe(ltv, 1e4, "LTV should not exceed 100% (1e4)."); // LTV is scaled by 1e4 (e.g. 8000 means 80%)
        assertGt(maxLev, 0, "Max leverage must be greater than zero.");
    }

    /**
     * @notice Tests the end-to-end flash leverage open and close operations.
     * @dev This test performs the following steps:
     * 1. Calculates the maximum flash loan amount for rETH collateral.
     * 2. Opens a leveraged position by:
     * - Providing rETH as initial collateral.
     * - Taking a DAI flash loan.
     * - Swapping DAI for more rETH (via Uniswap V3 and potentially Balancer).
     * - Supplying all rETH to Aave.
     * - Borrowing DAI from Aave to repay the flash loan.
     * 3. Verifies the health factor and position details after opening.
     * 4. Closes the leveraged position by:
     * - Taking a flash loan of rETH (collateral).
     * - Withdrawing rETH from Aave.
     * - Swapping a portion of rETH to DAI to repay the Aave DAI debt.
     * - Repaying the rETH flash loan.
     * 5. Verifies the health factor and position details after closing (should be zero debt/collateral on Aave).
     * 6. Checks the final DAI and rETH balances to determine profit/loss.
     */
    function test_flashLev() public {
        uint256 colAmount = 1e18; // Initial collateral amount: 1 rETH.

        // Get maximum flash loan parameters for the initial collateral.
        (uint256 maxFlashLoanUsd, uint256 price, uint256 ltv, uint256 maxLev) =
            flashLev.getMaxFlashLoanAmountUsd(RETH, colAmount);

        // Log these parameters.
        console.log("Max flash loan USD for open: %e", maxFlashLoanUsd);
        console.log("Collateral (RETH) price (USD scaled by 1e8): %e", price);
        console.log("Collateral (RETH) LTV on Aave (scaled by 1e4): %e", ltv);
        console.log("Max leverage factor (scaled by 1e18): %e", maxLev);

        console.log("--------- Initiating Flash Leverage Open ------------");

        // Determine the amount of DAI to flash loan, slightly less than max (98%) for safety/slippage.
        // Assumes 1 DAI is approximately 1 USD for this calculation.
        uint256 flashLoanDaiAmount = maxFlashLoanUsd * 98 / 100;

        // Prepare parameters for the open operation.
        FlashLev.OpenParams memory openParams = FlashLev.OpenParams({
            coin: DAI, // The coin to flash loan and borrow from Aave (DAI).
            collateral: RETH, // The collateral asset (rETH).
            colAmount: colAmount, // Initial amount of collateral provided by the user.
            coinAmount: flashLoanDaiAmount, // Amount of 'coin' (DAI) to flash loan.
            swap: FlashLev.SwapParams({
                // Minimum amount of collateral (rETH) expected from swapping the flash-loaned DAI.
                // (flashLoanDaiAmount / price_RETH_in_DAI) * 0.98 for 2% slippage.
                // Price is RETH/USD, so coinAmount / price is RETH amount (needs 1e8 scaling for price).
                amountOutMin: (flashLoanDaiAmount * 1e8 / price) * 98 / 100,
                // Encoded data for the swap:
                // bool: true indicates coinToCollateral (DAI to RETH).
                // uint24: Uniswap V3 pool fee for DAI/WETH (WETH is intermediate for RETH).
                // bytes32: Balancer pool ID for WETH/RETH swap.
                data: abi.encode(
                    true, // true for coin (DAI) to collateral (RETH) swap path
                    UNISWAP_V3_POOL_FEE_DAI_WETH,
                    BALANCER_POOL_ID_RETH_WETH
                )
            }),
            minHealthFactor: 101 * 1e16 // Target minimum health factor (1.01), scaled by 1e18.
        });

        // Execute the open operation via the proxy.
        proxy.execute(
            address(flashLev), // Target contract: FlashLev.
            abi.encodeCall(flashLev.open, (openParams)) // Encoded call data.
        );

        Info memory infoAfterOpen;
        infoAfterOpen = getInfo(address(proxy)); // Get Aave position info for the proxy contract.

        // Assertions after opening the leveraged position.
        assertGt(infoAfterOpen.col, 0, "Collateral in Aave should be greater than zero after open.");
        assertGt(infoAfterOpen.debt, 0, "Debt in Aave should be greater than zero after open.");
        assertGt(infoAfterOpen.hf, 1e18, "Health factor should be greater than 1 after open."); // HF > 1
        // Check if health factor is within a reasonable upper bound (e.g., less than 1.1, accounting for precision)
        // This depends on the target minHealthFactor and market conditions.
        assertLt(infoAfterOpen.hf, 110 * 1e16, "Health factor too high or minHealthFactor not effective.");


        console.log("--------- Initiating Flash Leverage Close ------------");
        uint256 daiBalanceBeforeClose = dai.balanceOf(address(this)); // DAI balance of test contract (owner of proxy).
        uint256 daiDebtOnAave = flashLev.getDebt(address(proxy), DAI); // Get current DAI debt of the proxy on Aave.

        // Prepare parameters for the close operation.
        FlashLev.CloseParams memory closeParams = FlashLev.CloseParams({
            coin: DAI, // The coin that was borrowed (DAI).
            collateral: RETH, // The collateral asset (rETH).
            colAmount: colAmount, // Amount of collateral to withdraw (all of it).
            swap: FlashLev.SwapParams({
                // Minimum amount of 'coin' (DAI) expected from swapping collateral (rETH) to repay debt.
                // Need enough DAI to cover daiDebtOnAave, allowing for 2% slippage.
                amountOutMin: daiDebtOnAave * 98 / 100,
                // Encoded data for the swap:
                // bool: false indicates collateralToCoin (RETH to DAI).
                // uint24: Uniswap V3 pool fee for WETH/DAI (WETH is intermediate for RETH).
                // bytes32: Balancer pool ID for RETH/WETH swap.
                data: abi.encode(
                    false, // false for collateral (RETH) to coin (DAI) swap path
                    UNISWAP_V3_POOL_FEE_DAI_WETH, // Fee for WETH/DAI part of the swap
                    BALANCER_POOL_ID_RETH_WETH // Balancer Pool ID for RETH/WETH part
                )
            })
        });

        // Execute the close operation via the proxy.
        proxy.execute(
            address(flashLev), // Target contract: FlashLev.
            abi.encodeCall(flashLev.close, (closeParams)) // Encoded call data.
        );

        uint256 daiBalanceAfterClose = dai.balanceOf(address(this)); // DAI balance after closing.

        Info memory infoAfterClose;
        infoAfterClose = getInfo(address(proxy)); // Get Aave position info for the proxy post-closure.

        // Assertions after closing the leveraged position.
        // Due to fees and potential minor dust amounts, Aave position might not be exactly zero.
        // For a full close, we expect debt and collateral to be zero, or very close to it.
        // Health Factor becomes irrelevant (often max uint) if debt is zero.
        assertEq(infoAfterClose.col, 0, "Collateral in Aave should be zero after close.");
        assertEq(infoAfterClose.debt, 0, "Debt in Aave should be zero after close.");
        // If col and debt are 0, HF is usually type(uint256).max.
        // If there's dust, it might be very high. Checking > 1e18 is a basic sanity check.
        assertGt(infoAfterClose.hf, 1e18, "Health factor should be high (or max) after close if debt is zero.");


        // Log profit or loss from the operation.
        if (daiBalanceAfterClose >= daiBalanceBeforeClose) {
            console.log("Profit in DAI: %e", daiBalanceAfterClose - daiBalanceBeforeClose);
        } else {
            console.log("Loss in DAI: %e", daiBalanceBeforeClose - daiBalanceAfterClose);
        }

        uint256 finalRethBalance = reth.balanceOf(address(this)); // rETH balance of the test contract.
        console.log("Final rETH Collateral balance of test contract: %e", finalRethBalance);

        // The initial rETH collateral (colAmount) should be returned to the test contract.
        // Allow for small discrepancies due to flash loan fees on collateral if applicable, or dust.
        // Here we expect it to be exact if the flash loan for closing was on the coin (DAI).
        // If the close flash loan was on collateral (rETH), then there might be a fee.
        // The current `close` implementation takes a flash loan of collateral.
        // Therefore, the finalRethBalance might be slightly less than colAmount due to Balancer flash loan fee.
        // For simplicity in this test, we'll assert it's close. A more precise check would account for fees.
        // The current test logic implies the initial `colAmount` is returned to the user (`address(this)`)
        // if no new collateral was acquired or lost beyond operational swap costs.
        // However, the `proxy` is the one interacting. `colAmount` was initially dealt to `address(this)`.
        // The `FlashLev` contract sends back the remaining collateral to `msg.sender` of `proxy.execute`, which is `address(this)`.
        // We expect the initial 1 rETH (colAmount) to be returned, minus any fees paid in rETH.
        // The current strategy description implies the user's *initial* collateral is eventually returned.
        // assertEq(finalRethBalance, colAmount, "Initial rETH collateral should be returned.");
        // Given Balancer flash loan fees are paid from the flash-loaned asset, final rETH should be close to colAmount.
        // A more robust check would be `assertApproxEqAbs(finalRethBalance, colAmount, some_fee_delta)`.
        // For this example, let's assume the goal is to get back the initial collateral.
        // If flash loan of collateral was used for close, and fee was paid from it, then `finalRethBalance` would be less.
        // The `FlashLev.close` function withdraws all collateral from Aave. Part is swapped to repay debt, rest is returned.
        // The test starts with `colAmount` of RETH in `address(this)`. This is sent to the proxy.
        // At the end, the remaining RETH should be back in `address(this)`.
        // The profit/loss is primarily measured in DAI.
        // The test expects to recover the *initial* `colAmount` of rETH.
        assertEq(finalRethBalance, colAmount, "Initial RETH collateral amount should be returned to the test contract.");
    }
}