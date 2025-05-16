// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "../interfaces/IERC20.sol";
import {IVault} from "../interfaces/balancer/IVault.sol";
import {ISwapRouter} from "../interfaces/uniswap/ISwapRouter.sol";
import {
    WETH, BALANCER_VAULT, UNISWAP_V3_SWAP_ROUTER_02
} from "./Constants.sol";

/// @title SwapHelper
/// @notice A helper contract that facilitates token swaps using Uniswap V3 and Balancer V2.
/// @dev This contract provides functions to perform token swaps between two different protocols
//       (Uniswap V3 and Balancer V2).
abstract contract SwapHelper {
    /// @dev The WETH token interface
    IERC20 internal constant weth = IERC20(WETH);

    /// @dev The Balancer Vault interface
    IVault internal constant vault = IVault(BALANCER_VAULT);

    /// @dev The Uniswap V3 Router interface
    ISwapRouter internal constant router =
        ISwapRouter(UNISWAP_V3_SWAP_ROUTER_02);

    /// @notice Swaps tokens on Uniswap V3
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param fee The pool fee to be used on Uniswap V3
    /// @param amountIn The amount of the input token to swap
    /// @param amountOutMin The minimum amount of the output token to receive
    /// @param receiver The address to receive the output tokens
    /// @return amountOut The amount of the output token received
    /// @dev This function performs a swap on Uniswap V3 using `exactInputSingle` method.
    function swapUniV3(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 amountOutMin,
        address receiver
    ) internal returns (uint256 amountOut) {
        return router.exactInputSingle(
            ISwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: receiver,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            })
        );
    }

    /// @notice Swaps tokens on Balancer V2
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param poolId The pool ID to use for the swap
    /// @param amountIn The amount of the input token to swap
    /// @param amountOutMin The minimum amount of the output token to receive
    /// @param receiver The address to receive the output tokens
    /// @return amountOut The amount of the output token received
    /// @dev This function performs a swap on Balancer V2 using the `swap` method from the Vault contract.
    function swapBalancerV2(
        address tokenIn,
        address tokenOut,
        bytes32 poolId,
        uint256 amountIn,
        uint256 amountOutMin,
        address receiver
    ) internal returns (uint256 amountOut) {
        return vault.swap({
            singleSwap: IVault.SingleSwap({
                poolId: poolId,
                kind: IVault.SwapKind.GIVEN_IN,
                assetIn: tokenIn,
                assetOut: tokenOut,
                amount: amountIn,
                userData: ""
            }),
            funds: IVault.FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: receiver,
                toInternalBalance: false
            }),
            limit: amountOutMin,
            deadline: block.timestamp
        });
    }

    /// @notice Executes a token swap, either starting with Uniswap V3 or Balancer V2
    //          depending on the direction of the swap
    /// @param tokenIn The input token address
    /// @param tokenOut The output token address
    /// @param amountIn The amount of the input token to swap
    /// @param amountOutMin The minimum amount of the output token to receive
    /// @param data Additional data to control the swap behavior (direction, pool IDs, etc.)
    /// @return amountOut The amount of the output token received
    /// @dev This function determines the direction of the swap based on the provided `data`,
    //       and swaps using either Uniswap V3 or Balancer V2.
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 amountOutMin,
        bytes memory data
    ) internal returns (uint256 amountOut) {
        // Decode the direction (open/close), Uniswap pool fee, and Balancer pool ID from the provided data
        (bool open, uint24 uniV3PoolFee, bytes32 balPoolId) =
            abi.decode(data, (bool, uint24, bytes32));

        // Perform token swap from tokenIn to tokenOut
        if (open) {
            // TokenIn -> Uniswap -> WETH -> Balancer -> TokenOut
            IERC20(tokenIn).approve(address(router), amountIn);

            uint256 wethAmountOut = swapUniV3({
                tokenIn: tokenIn,
                tokenOut: WETH,
                fee: uniV3PoolFee,
                amountIn: amountIn,
                amountOutMin: 1,
                receiver: address(this)
            });

            weth.approve(address(vault), wethAmountOut);

            return swapBalancerV2({
                tokenIn: WETH,
                tokenOut: tokenOut,
                poolId: balPoolId,
                amountIn: wethAmountOut,
                amountOutMin: amountOutMin,
                receiver: address(this)
            });
        } else {
            // TokenIn -> Balancer -> WETH -> Uniswap -> TokenOut
            IERC20(tokenIn).approve(address(vault), amountIn);

            uint256 wethAmountOut = swapBalancerV2({
                tokenIn: tokenIn,
                tokenOut: WETH,
                poolId: balPoolId,
                amountIn: amountIn,
                amountOutMin: 1,
                receiver: address(this)
            });

            weth.approve(address(router), wethAmountOut);

            return swapUniV3({
                tokenIn: address(weth),
                tokenOut: tokenOut,
                fee: uniV3PoolFee,
                amountIn: wethAmountOut,
                amountOutMin: amountOutMin,
                receiver: address(this)
            });
        }
    }
}
