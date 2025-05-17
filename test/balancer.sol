// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title BalancerTest
/// @notice Test contract for interacting with Balancer V2 liquidity pools
/// @dev Uses Forge testing framework to test BalancerLiquidity contract functionality
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {IVault} from "@src/interfaces/balancer/IVault.sol";
import {
    WETH,
    RETH,
    BALANCER_VAULT,
    BALANCER_POOL_RETH_WETH,
    BALANCER_POOL_ID_RETH_WETH
} from "@src/helpers/Constants.sol";
import {BalancerLiquidity} from "@src/BalancerLiquidity.sol";

// forge test --fork-url $FORK_URL --match-path test/balancer.sol -vvv

contract BalancerTest is Test {
    /// @notice rETH token interface
    IRETH private immutable reth = IRETH(RETH);
    /// @notice WETH token interface
    IERC20 private immutable weth = IERC20(WETH);
    /// @notice Balancer Vault interface
    IVault private immutable vault = IVault(BALANCER_VAULT);
    /// @notice Balancer Pool Token (BPT) interface
    IERC20 private immutable bpt = IERC20(BALANCER_POOL_RETH_WETH);

    /// @notice Instance of BalancerLiquidity contract
    BalancerLiquidity private liq;

    /// @notice Sets up the test environment
    /// @dev Initializes token balances, deploys BalancerLiquidity, and sets approvals
    function setUp() public {
        // Fund this contract with 1 ETH worth of WETH and rETH
        deal(WETH, address(this), 1e18);
        deal(RETH, address(this), 1e18);

        // Deploy BalancerLiquidity contract
        liq = new BalancerLiquidity();

        // Approve BalancerLiquidity to spend tokens
        reth.approve(address(liq), type(uint256).max);
        weth.approve(address(liq), type(uint256).max);
        bpt.approve(address(liq), type(uint256).max);
    }

    /// @notice Tests joining the Balancer rETH/WETH pool
    /// @dev Verifies token balances and BPT issuance after joining
    function test_join() public {
        uint256 rethAmount = 1e18; // 1 rETH
        uint256 wethAmount = 1e18; // 1 WETH

        // Join the Balancer pool with specified amounts
        liq.join(rethAmount, wethAmount);

        // Log BPT balance for debugging
        uint256 bptBal = bpt.balanceOf(address(this));
        console.log("BPT: %e", bptBal);

        // Verify tokens were consumed
        assertEq(reth.balanceOf(address(this)), 0, "rETH balance should be 0");
        assertEq(weth.balanceOf(address(this)), 0, "WETH balance should be 0");
        // Verify BPT was received
        assertGt(bpt.balanceOf(address(this)), 0, "BPT balance should be greater than 0");

        // Verify BalancerLiquidity contract has no leftover tokens
        assertEq(reth.balanceOf(address(liq)), 0, "Liquidity contract rETH balance should be 0");
        assertEq(weth.balanceOf(address(liq)), 0, "Liquidity contract WETH balance should be 0");
        assertEq(bpt.balanceOf(address(liq)), 0, "Liquidity contract BPT balance should be 0");
    }

    /// @notice Tests exiting the Balancer rETH/WETH pool
    /// @dev Verifies token balances and BPT burn after exiting
    function test_exit() public {
        uint256 rethAmount = 1e18; // 1 rETH
        uint256 wethAmount = 1e18; // 1 WETH

        // Join the pool first to get BPT
        liq.join(rethAmount, wethAmount);

        // Set minimum rETH amount to 90% of input to account for slippage
        uint256 minRethAmount = (rethAmount + wethAmount) * 90 / 100;

        // Exit the pool with all BPT
        uint256 bptBal = bpt.balanceOf(address(this));
        liq.exit(bptBal, minRethAmount);

        // Log balances for debugging
        console.log("BPT: %e", bpt.balanceOf(address(this)));
        console.log("RETH: %e", reth.balanceOf(address(this)));
        console.log("WETH: %e", weth.balanceOf(address(this)));

        // Verify rETH was received
        assertGt(reth.balanceOf(address(this)), 0, "rETH balance should be greater than 0");
        // Verify WETH was not received (pool may return single asset)
        assertEq(weth.balanceOf(address(this)), 0, "WETH balance should be 0");
        // Verify all BPT was burned
        assertEq(bpt.balanceOf(address(this)), 0, "BPT balance should be 0");

        // Verify BalancerLiquidity contract has no leftover tokens
        assertEq(reth.balanceOf(address(liq)), 0, "Liquidity contract rETH balance should be 0");
        assertEq(weth.balanceOf(address(liq)), 0, "Liquidity contract WETH balance should be 0");
        assertEq(bpt.balanceOf(address(liq)), 0, "Liquidity contract BPT balance should be 0");
    }
}