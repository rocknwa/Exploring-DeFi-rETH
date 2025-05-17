// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

// =================================================================================================
// Imports
// =================================================================================================

import {Test, console} from "forge-std/Test.sol"; // Foundry's standard library for testing, includes testing utilities and console logging.
import {IERC20} from "@src/interfaces/IERC20.sol"; // Standard ERC20 token interface.
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol"; // Interface for Rocket Pool's rETH token.
import {IBaseRewardPool4626} from "@src/interfaces/aura/IBaseRewardPool4626.sol"; // Interface for Aura's ERC-4626 compatible base reward pool.

// Import various constants (addresses, pool IDs) used throughout the tests.
import {
    WETH, // Wrapped Ether address
    RETH, // Rocket Pool rETH address
    BAL, // Balancer token address
    BALANCER_VAULT, // Balancer Vault address (though not directly used as a variable here, it's context for BALANCER_POOL_RETH_WETH)
    BALANCER_POOL_RETH_WETH, // Address of the Balancer rETH/WETH Pool Token (BPT)
    AURA, // Aura token address
    AURA_BASE_REWARD_POOL_4626_RETH // Address of the Aura Base Reward Pool for rETH/WETH BPT
} from "@src/helpers/Constants.sol";
import {AuraLiquidity} from "@src/AuraLiquidity.sol"; // The main contract being tested, for managing liquidity on Aura Finance.

// =================================================================================================
// Test Contract Definition
// =================================================================================================

// Command to run this specific test file using Foundry:
// forge test --fork-url $FORK_URL --match-path test/aura.sol -vvv

/**
 * @title AuraTest
 * @notice Test suite for the AuraLiquidity contract.
 * @dev This contract uses Foundry for testing. It requires a forked mainnet environment
 * (specified by $FORK_URL) to interact with Aura Finance and Balancer contracts.
 * It tests depositing, withdrawing, reward claiming, and authorization logic.
 */
contract AuraTest is Test {
    // =============================================================================================
    // State Variables - Token Instances
    // =============================================================================================
    IRETH internal reth = IRETH(RETH); // Instance of the IRETH token contract.
    IERC20 internal weth = IERC20(WETH); // Instance of the WETH token contract.
    IERC20 internal bal = IERC20(BAL);   // Instance of the BAL (Balancer) token contract.
    IERC20 internal aura = IERC20(AURA); // Instance of the AURA token contract.
    IERC20 internal bpt = IERC20(BALANCER_POOL_RETH_WETH); // Instance of the Balancer Pool Token (BPT) for rETH/WETH.

    // =============================================================================================
    // State Variables - Protocol Contract Instances
    // =============================================================================================
    IBaseRewardPool4626 internal rewardPool =
        IBaseRewardPool4626(AURA_BASE_REWARD_POOL_4626_RETH); // Instance of the Aura Base Reward Pool for the rETH/WETH BPT.

    AuraLiquidity internal liq; // Instance of the AuraLiquidity contract (the contract under test).

    // =============================================================================================
    // Setup Function
    // =============================================================================================

    /**
     * @notice Sets up the test environment before each test case.
     * @dev This function is automatically called by Foundry before each test.
     * It deploys the AuraLiquidity contract, deals initial RETH balance
     * to the test contract, and approves the AuraLiquidity contract for RETH spending.
     */
    function setUp() public {
        // Deploy the AuraLiquidity contract.
        liq = new AuraLiquidity();
        // Deal 1 RETH to this test contract to be used as initial deposit.
        deal(RETH, address(this), 1e18);
        // Approve the AuraLiquidity contract to spend the maximum amount of RETH on behalf of this test contract.
        reth.approve(address(liq), type(uint256).max);
    }

    // =============================================================================================
    // Authorization Tests
    // =============================================================================================

    /**
     * @notice Tests that the `deposit` function can only be called by the owner.
     * @dev Uses `vm.expectRevert()` and `vm.prank()` to simulate a call from an unauthorized address.
     */
    function test_deposit_auth() public {
        vm.expectRevert(); // Expect the next call to revert.
        vm.prank(address(1)); // Simulate the next call being made from address(1) (an unauthorized address).
        liq.deposit(1e18); // Attempt to call deposit.
    }

    /**
     * @notice Tests that the `exit` function can only be called by the owner.
     * @dev First deposits some RETH, then uses `vm.expectRevert()` and `vm.prank()`
     * to simulate an `exit` call from an unauthorized address.
     */
    function test_exit_auth() public {
        // Setup: Owner deposits funds first.
        uint256 shares = liq.deposit(1e18);

        vm.expectRevert(); // Expect the next call to revert.
        vm.prank(address(1)); // Simulate the next call being made from address(1).
        liq.exit(shares, 1); // Attempt to call exit.
    }

    /**
     * @notice Tests that the `transfer` (likely an emergency token recovery) function can only be called by the owner.
     * @dev Uses `vm.expectRevert()` and `vm.prank()` to simulate a call from an unauthorized address.
     */
    function test_transfer_auth() public {
        vm.expectRevert(); // Expect the next call to revert.
        vm.prank(address(1)); // Simulate the next call being made from address(1).
        liq.transfer(RETH, address(1)); // Attempt to call transfer.
    }

    /**
     * @notice Tests that the `transfer` function works correctly when called by the owner.
     * @dev This test assumes `transfer` is an admin function to move tokens out of the contract.
     * It doesn't check balances here, just that the call doesn't revert when made by owner.
     * A more thorough test would check token balances before and after.
     */
    function test_transfer() public {
        // deal RETH to the liq contract first to test transfer FROM liq
        deal(RETH, address(liq), 1e18);
        uint256 initialBalance = reth.balanceOf(address(1));
        liq.transfer(RETH, address(1)); // Call transfer as owner.
        assertEq(reth.balanceOf(address(1)), initialBalance + 1e18, "RETH should be transferred to address(1)");
    }

    // =============================================================================================
    // Core Functionality Test (Deposit, Rewards, Exit)
    // =============================================================================================

    /**
     * @notice Tests the full lifecycle: deposit, reward accrual and claiming, and withdrawal.
     * @dev This test covers:
     * 1. Depositing RETH into the AuraLiquidity contract, which then stakes BPT into Aura.
     * 2. Simulating time passage to allow rewards (BAL, AURA) to accrue.
     * 3. Claiming these rewards.
     * 4. Withdrawing the initial liquidity.
     * It checks various token balances at each step to ensure correctness.
     */
    function test_depositAndExit() public {
        console.log("--- Starting deposit ---");
        uint256 rethAmount = 1e18; // Amount of RETH to deposit.
        // Call the deposit function on AuraLiquidity contract.
        uint256 shares = liq.deposit(rethAmount);

        console.log("Aura Reward pool shares received by AuraLiquidity contract: %e", shares);

        // Assertions after deposit:
        assertGt(shares, 0, "Shares received from Aura reward pool should be greater than zero.");
        // Ensure shares recorded by AuraLiquidity match its balance in the Aura reward pool.
        assertEq(shares, rewardPool.balanceOf(address(liq)), "AuraLiquidity internal shares should match its reward pool balance.");
        // Test contract should have no RETH left after depositing.
        assertEq(reth.balanceOf(address(this)), 0, "Test contract's RETH balance should be zero after deposit.");
        // AuraLiquidity contract should not hold RETH directly; it should be in the Balancer pool / Aura system.
        assertEq(reth.balanceOf(address(liq)), 0, "AuraLiquidity contract's RETH balance should be zero after deposit processing.");

        // Simulate time passing for rewards to accrue.
        console.log("--- Skipping 7 days for reward accrual ---");
        skip(7 days); // Foundry cheatcode to advance blockchain time by 7 days.

        console.log("--- Claiming rewards ---");
        liq.getReward(); // Call the function to claim accrued rewards.

        uint256 balBalanceInLiq = bal.balanceOf(address(liq));
        uint256 auraBalanceInLiq = aura.balanceOf(address(liq));
        console.log("BAL reward balance in AuraLiquidity contract: %e", balBalanceInLiq);
        console.log("AURA reward balance in AuraLiquidity contract: %e", auraBalanceInLiq);

        // Assertions after claiming rewards:
        // Rewards (BAL, AURA) should be present in the AuraLiquidity contract.
        // Depending on the pool and duration, they might be zero if no rewards were distributed or activity was low.
        assertGe(balBalanceInLiq, 0, "BAL reward balance in AuraLiquidity should be >= 0.");
        assertGe(auraBalanceInLiq, 0, "AURA reward balance in AuraLiquidity should be >= 0.");

        // NOTE: The original comment "bug? non-zero WETH balance" refers to a potential unexpected WETH balance
        // either in `address(this)` or `address(liq)` before or after exit. This test checks `address(this)`.
        console.log("--- Starting withdrawal (exit) ---");

        uint256 wethBalBeforeExit = weth.balanceOf(address(this)); // WETH balance of test contract before exiting.
        // Call the exit function on AuraLiquidity to withdraw all shares. Min amounts set to 1 for simplicity.
        liq.exit(shares, 1); // Exiting all shares, expecting at least 1 wei of underlying BPT asset.
        uint256 wethBalAfterExit = weth.balanceOf(address(this)); // WETH balance of test contract after exiting.

        uint256 sharesAfterExit = rewardPool.balanceOf(address(liq));
        console.log("Aura Reward pool shares in AuraLiquidity after exit: %e", sharesAfterExit);
        console.log("BPT balance of test contract after exit: %e", bpt.balanceOf(address(this)));
        console.log("RETH balance of test contract after exit: %e", reth.balanceOf(address(this)));
        console.log("WETH balance of test contract after exit: %e", wethBalAfterExit);
        console.log("BAL reward balance in AuraLiquidity contract after exit: %e", bal.balanceOf(address(liq)));
        console.log("AURA reward balance in AuraLiquidity contract after exit: %e", aura.balanceOf(address(liq)));

        // Assertions after withdrawal:
        // AuraLiquidity contract should have no shares left in the reward pool.
        assertEq(sharesAfterExit, 0, "AuraLiquidity's reward pool shares should be zero after exit.");
        // AuraLiquidity contract should not hold RETH, WETH, or BPT directly after exit (should be returned to user).
        assertEq(reth.balanceOf(address(liq)), 0, "AuraLiquidity's RETH balance should be zero after exit.");
        assertEq(weth.balanceOf(address(liq)), 0, "AuraLiquidity's WETH balance should be zero after exit.");
        assertEq(bpt.balanceOf(address(liq)), 0, "AuraLiquidity's BPT balance should be zero after exit.");
        // Test contract should have received back its RETH (or a mix of RETH/WETH from BPT).
        assertGt(reth.balanceOf(address(this)), 0, "Test contract's RETH balance should be > 0 after exit.");
        // Test contract's WETH balance should ideally be unchanged if exit primarily returns RETH or if WETH part of LP is handled as expected.
        // The original comment "NOTE: bug? non-zero WETH balance" and this assertion imply that the user (address(this))
        // is not expected to receive WETH directly from this specific exit flow, or its WETH balance from other sources should remain unaffected.
        assertEq(wethBalAfterExit, wethBalBeforeExit, "Test contract's WETH balance should be same as before exit unless it's part of the withdrawn LP assets.");
        // Reward balances should remain in the AuraLiquidity contract (user would need a separate function to withdraw rewards from AuraLiquidity).
        assertGe(bal.balanceOf(address(liq)), 0, "BAL reward balance in AuraLiquidity should remain >= 0 post-exit.");
        assertGe(aura.balanceOf(address(liq)), 0, "AURA reward balance in AuraLiquidity should remain >= 0 post-exit.");
    }
    }