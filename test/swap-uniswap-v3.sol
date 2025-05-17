// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title UniswapV3SwapTest
/// @notice Test suite for SwapUniswapV3 contract functionality
/// @dev Uses Forge testing framework to test WETH to rETH and rETH to WETH swaps on Uniswap V3
import {Test, console} from "forge-std/Test.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {ISwapRouter} from "@src/interfaces/uniswap/ISwapRouter.sol";
import {
    RETH,
    WETH,
    UNISWAP_V3_SWAP_ROUTER_02,
    UNISWAP_V3_POOL_FEE_RETH_WETH
} from "@src/helpers/Constants.sol";
import {SwapUniswapV3} from "@src/SwapUniswapV3.sol";

// forge test --fork-url $FORK_URL --match-path test/swap-uniswap-v3.sol -vvv

contract UniswapV3SwapTest is Test {
    /// @notice rETH token interface
    IRETH internal constant reth = IRETH(RETH);
    /// @notice WETH token interface
    IERC20 internal constant weth = IERC20(WETH);
    /// @notice Instance of SwapUniswapV3 contract
    SwapUniswapV3 internal swap;

    /// @notice Sets up the test environment
    /// @dev Deploys SwapUniswapV3 contract
    function setUp() public {
        // Deploy SwapUniswapV3 contract
        swap = new SwapUniswapV3();
    }

    /// @notice Tests swapping WETH to rETH on Uniswap V3
    /// @dev Verifies token balances after the swap
    function test_swapWethToReth() public {
        // Fund this contract with 1 WETH
        uint256 wethAmount = 1e18;
        deal(WETH, address(this), wethAmount);

        // Approve SwapUniswapV3 to spend WETH
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

    /// @notice Tests swapping rETH to WETH on Uniswap V3
    /// @dev Verifies token balances after the swap
    function test_swapRethToWeth() public {
        // Fund this contract with 1 rETH
        uint256 rEthAmount = 1e18;
        deal(RETH, address(this), rEthAmount);

        // Approve SwapUniswapV3 to spend rETH
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