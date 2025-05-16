// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "./interfaces/IERC20.sol";
import {IRETH} from "./interfaces/rocket-pool/IRETH.sol";
import {IVault} from "./interfaces/balancer/IVault.sol";
import {
    WETH,
    RETH,
    BALANCER_VAULT,
    BALANCER_POOL_RETH_WETH,
    BALANCER_POOL_ID_RETH_WETH
} from "./helpers/Constants.sol";

/// @title BalancerLiquidity
/// @notice This contract allows users to join or exit the Balancer RETH/WETH liquidity pool
//          by interacting with the Balancer Vault.
/// @dev The contract facilitates both single-sided and double-sided liquidity provision
//       to the Balancer pool. Users can deposit RETH and/or WETH to earn Balancer Pool Tokens (BPT).
contract BalancerLiquidity {
    IRETH private constant reth = IRETH(RETH);
    IERC20 private constant weth = IERC20(WETH);
    IVault private constant vault = IVault(BALANCER_VAULT);
    // Balancer Pool Token
    IERC20 private constant bpt = IERC20(BALANCER_POOL_RETH_WETH);

    /// @notice Internal function to join the Balancer RETH/WETH liquidity pool
    /// @param recipient The address receiving the Balancer Pool Tokens (BPT)
    /// @param assets The array of token addresses to provide as liquidity (RETH and WETH)
    /// @param maxAmountsIn The maximum amounts of each token to deposit into the pool
    /// @dev This function uses the Balancer Vault's `joinPool` function to add liquidity to the pool.
    ///      It encodes the request data to specify the kind of join operation and the desired amounts.
    function _join(
        address recipient,
        address[] memory assets,
        uint256[] memory maxAmountsIn
    ) private {
        vault.joinPool({
            poolId: BALANCER_POOL_ID_RETH_WETH,
            sender: address(this),
            recipient: recipient,
            request: IVault.JoinPoolRequest({
                assets: assets,
                maxAmountsIn: maxAmountsIn,
                // EXACT_TOKENS_IN_FOR_BPT_OUT, amounts, min BPT
                userData: abi.encode(
                    IVault.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT,
                    maxAmountsIn,
                    uint256(1)
                ),
                fromInternalBalance: false
            })
        });
    }

    /// @notice Internal function to exit the Balancer RETH/WETH liquidity pool
    /// @param bptAmount The amount of Balancer Pool Tokens (BPT) to burn
    /// @param recipient The address receiving the withdrawn tokens (RETH and/or WETH)
    /// @param assets The array of token addresses to withdraw from the pool (RETH and WETH)
    /// @param minAmountsOut The minimum amounts of each token to withdraw from the pool
    /// @dev This function uses the Balancer Vault's `exitPool` function to remove liquidity from the pool.
    ///      It encodes the request data to specify the kind of exit operation and the desired amounts.
    function _exit(
        uint256 bptAmount,
        address recipient,
        address[] memory assets,
        uint256[] memory minAmountsOut
    ) private {
        vault.exitPool({
            poolId: BALANCER_POOL_ID_RETH_WETH,
            sender: address(this),
            recipient: recipient,
            request: IVault.ExitPoolRequest({
                assets: assets,
                minAmountsOut: minAmountsOut,
                // EXACT_BPT_IN_FOR_ONE_TOKEN_OUT, BPT amount, index of token to withdraw
                userData: abi.encode(
                    IVault.ExitKind.EXACT_BPT_IN_FOR_ONE_TOKEN_OUT,
                    bptAmount,
                    // RETH
                    uint256(0)
                ),
                toInternalBalance: false
            })
        });
    }

    /// @notice Deposit RETH and/or WETH into the Balancer liquidity pool
    /// @param rethAmount The amount of RETH to deposit
    /// @param wethAmount The amount of WETH to deposit
    /// @dev This function allows the user to provide liquidity to the RETH/WETH Balancer pool.
    ///      It accepts both RETH and WETH as input and approves the respective tokens for the Vault.
    ///      The user receives Balancer Pool Tokens (BPT) as a representation of their share in the pool.
    function join(uint256 rethAmount, uint256 wethAmount) external {
           if (rethAmount > 0) {
            reth.transferFrom(msg.sender, address(this), rethAmount);
            reth.approve(address(vault), rethAmount);
        }
        if (wethAmount > 0) {
            weth.transferFrom(msg.sender, address(this), wethAmount);
            weth.approve(address(vault), wethAmount);
        }

        // Tokens must be ordered numerically by token address
        address[] memory assets = new address[](2);
        assets[0] = RETH;
        assets[1] = WETH;

        // Single sided or both liquidity is possible
        uint256[] memory maxAmountsIn = new uint256[](2);
        maxAmountsIn[0] = rethAmount;
        maxAmountsIn[1] = wethAmount;

        _join(msg.sender, assets, maxAmountsIn);

        uint256 rethBal = reth.balanceOf(address(this));
        if (rethBal > 0) {
            reth.transfer(msg.sender, rethBal);
        }

        uint256 wethBal = weth.balanceOf(address(this));
        if (wethBal > 0) {
            weth.transfer(msg.sender, wethBal);
        }
    }

    /// @notice Exit the Balancer liquidity pool and withdraw RETH and/or WETH
    /// @param bptAmount The amount of Balancer Pool Tokens (BPT) to redeem
    /// @param minRethAmountOut The minimum amount of RETH to receive from the exit
    /// @dev This function allows the user to withdraw their share of liquidity from the RETH/WETH Balancer pool.
    ///      It performs an exit from the pool and returns RETH and/or WETH.
    function exit(uint256 bptAmount, uint256 minRethAmountOut) external {
 bpt.transferFrom(msg.sender, address(this), bptAmount);

        // Tokens must be ordered numerically by token address
        address[] memory assets = new address[](2);
        assets[0] = RETH;
        assets[1] = WETH;

        // Both single and all tokens are possible
        uint256[] memory minAmountsOut = new uint256[](2);
        minAmountsOut[0] = minRethAmountOut;
        minAmountsOut[1] = 0;

        _exit(bptAmount, msg.sender, assets, minAmountsOut);
    }
}
