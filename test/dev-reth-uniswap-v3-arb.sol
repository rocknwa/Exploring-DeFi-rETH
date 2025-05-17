// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title RethUniswapArb
/// @notice Test contract for arbitrage between Rocket Pool and Uniswap V3
/// @dev Uses Forge testing framework to simulate arbitrage strategies
import {Test, console} from "forge-std/Test.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {IRocketDepositPool} from "@src/interfaces/rocket-pool/IRocketDepositPool.sol";
import {ISwapRouter} from "@src/interfaces/uniswap/ISwapRouter.sol";
import {
    RETH,
    WETH,
    ROCKET_DEPOSIT_POOL,
    UNISWAP_V3_SWAP_ROUTER_02,
    UNISWAP_V3_POOL_FEE_RETH_WETH
} from "@src/helpers/Constants.sol";
import {SwapUniswapV3} from "@src/SwapUniswapV3.sol";

// forge test --fork-url $FORK_URL --match-path test/dev-reth-uniswap-v3-arb.sol -vvv

contract RethUniswapArb is Test {
    /// @notice rETH token interface
    IRETH internal constant reth = IRETH(RETH);
    /// @notice WETH token interface
    IERC20 internal constant weth = IERC20(WETH);
    /// @notice Rocket Pool deposit pool interface
    IRocketDepositPool internal constant depositPool = IRocketDepositPool(ROCKET_DEPOSIT_POOL);
    /// @notice Uniswap V3 swap router interface
    ISwapRouter internal constant router = ISwapRouter(UNISWAP_V3_SWAP_ROUTER_02);

    /// @notice Tests arbitrage from Rocket Pool to Uniswap V3 (ETH -> rETH -> WETH)
    /// @dev Deposits ETH to Rocket Pool, swaps rETH for WETH on Uniswap V3
    function test_arb_rocket_pool_to_uni_v3() public {
        // Deposit 1 ETH to Rocket Pool to receive rETH
        depositPool.deposit{value: 1e18}();

        // Get rETH balance after deposit
        uint256 rEthBal = reth.balanceOf(address(this));

        // Approve Uniswap router to spend rETH
        reth.approve(address(router), rEthBal);

        // Swap rETH for WETH on Uniswap V3
        uint256 wethAmount = router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: RETH,
                tokenOut: WETH,
                fee: UNISWAP_V3_POOL_FEE_RETH_WETH,
                recipient: address(this),
                amountIn: rEthBal,
                amountOutMinimum: 1, // Minimal slippage protection
                sqrtPriceLimitX96: 0 // No price limit
            })
        );

        // Log WETH received for debugging
        console.log("WETH %e", wethAmount);
    }

    /// @notice Enables receiving ETH
    /// @dev Required for Rocket Pool ETH withdrawals
    receive() external payable {}

    /// @notice Tests arbitrage from Uniswap V3 to Rocket Pool (WETH -> rETH -> ETH)
    /// @dev Swaps WETH for rETH on Uniswap V3, burns rETH for ETH via Rocket Pool
    function test_arb_uni_v3_to_rocket_pool() public {
        // Fund Rocket Pool deposit pool with 10 ETH to ensure sufficient liquidity
        (bool ok,) = RETH.call{value: 10 * 1e18}("");
        require(ok, "Send ETH failed");

        // Fund this contract with 1 WETH
        uint256 wethBal = 1e18;
        deal(address(weth), address(this), wethBal);

        // Approve Uniswap router to spend WETH
        weth.approve(address(router), wethBal);

        // Swap WETH for rETH on Uniswap V3
        uint256 rethAmount = router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: WETH,
                tokenOut: RETH,
                fee: UNISWAP_V3_POOL_FEE_RETH_WETH,
                recipient: address(this),
                amountIn: wethBal,
                amountOutMinimum: 1, // Minimal slippage protection
                sqrtPriceLimitX96: 0 // No price limit
            })
        );

        // Record ETH balance before burning rETH
        uint256 ethBalBefore = address(this).balance;

        // Burn rETH to receive ETH via Rocket Pool
        reth.burn(rethAmount);

        // Calculate ETH received
        uint256 ethBalAfter = address(this).balance;

        // Log ETH received for debugging
        console.log("WETH %e", ethBalAfter - ethBalBefore);
    }
}