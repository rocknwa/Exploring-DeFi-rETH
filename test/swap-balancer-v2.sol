// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title BalancerV2SwapTest
/// @notice Test suite for SwapBalancerV2 contract functionality
/// @dev Uses Forge testing framework to test WETH to rETH and rETH to WETH swaps on Balancer V2
import {Test, console} from "forge-std/Test.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {IVault} from "@src/interfaces/balancer/IVault.sol";
import {RETH, WETH} from "@src/helpers/Constants.sol";
import {SwapBalancerV2} from "@src/SwapBalancerV2.sol";

// forge test --fork-url $FORK_URL --match-path test/swap-balancer-v2.sol -vvv

contract BalancerV2SwapTest is Test {
    /// @notice rETH token interface
    IRETH internal constant reth = IRETH(RETH);
    /// @notice WETH token interface
    IERC20 internal constant weth = IERC20(WETH);
    /// @notice Instance of SwapBalancerV2 contract
    SwapBalancerV2 internal swap;

    /// @notice Sets up the test environment
    /// @dev Deploys SwapBalancerV2 contract
    function setUp() public {
        // Deploy SwapBalancerV2 contract
        swap = new SwapBalancerV2();
    }

    /// @notice Tests swapping WETH to rETH on Balancer V2
    /// @dev Verifies token balances after the swap
    function test_swapWethToReth() public {
        // Fund this contract with 1 WETH
        uint256 wethAmount = 1e18;
        deal(WETH, address(this), wethAmount);

        // Approve SwapBalancerV2 to spend WETH
        weth.approve(address(swap), wethAmount);

        // Perform WETH to rETH swap with minimal slippage protection
        swap.swapWethToReth(wethAmount, 1);

        // Log rETH balance for debugging
        uint256 rEthBal = reth.balanceOf(address(swap));
        console.log("rETH balance %e", rEthBal);

        // Verify rETH was received
        assertGt(rEthBal, 0, "rETH balance should be greater than 0");
        // Verify no WETH remains in swap contract
        assertEq(weth.balanceOf(address(swap)), 0, "WETH balance should be 0");
    }

    /// @notice Tests swapping rETH to WETH on Balancer V2
    /// @dev Verifies token balances after the swap
    function test_swapRethToWeth() public {
        // Fund this contract with 1 rETH
        uint256 rEthAmount = 1e18;
        deal(RETH, address(this), rEthAmount);

        // Approve SwapBalancerV2 to spend rETH
        reth.approve(address(swap), rEthAmount);

        // Perform rETH to WETH swap with minimal slippage protection
        swap.swapRethToWeth(rEthAmount, 1);

        // Log WETH balance for debugging
        uint256 wethBal = weth.balanceOf(address(swap));
        console.log("WETH balance %e", wethBal);

        // Verify WETH was received
        assertGt(wethBal, 0, "WETH balance should be greater than 0");
        // Verify no rETH remains in swap contract
        assertEq(reth.balanceOf(address(swap)), 0, "rETH balance should be 0");
    }
}