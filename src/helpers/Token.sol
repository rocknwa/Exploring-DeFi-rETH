// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {IERC20} from "../interfaces/IERC20.sol";

/// @title Token
/// @notice A simple contract to interact with ERC20 tokens for approval and transfers.
/// @dev This contract allows for token approval and transferring ERC20 tokens between addresses.
contract Token {
    /// @notice Approves a spender to spend a specific amount of tokens on behalf of the caller
    /// @param token The ERC20 token address to approve
    /// @param spender The address to be approved for spending the tokens
    /// @param amount The amount of tokens the spender is allowed to transfer
    /// @dev This function calls the `approve` method of the ERC20 token contract
    //       to allow the spender to use the specified amount.
    function approve(address token, address spender, uint256 amount) external {
        IERC20(token).approve(spender, amount);
    }

    /// @notice Transfers a specified amount of tokens to a destination address
    /// @param token The ERC20 token address to transfer
    /// @param dst The destination address to receive the tokens
    /// @param amount The amount of tokens to transfer
    /// @dev This function calls the `transfer` method of the ERC20 token contract
    //       to send tokens to the destination address.
    //       It also ensures the destination address is not the zero address.
    function transfer(address token, address dst, uint256 amount) external {
        require(dst != address(0), "dst = 0 addr");
        IERC20(token).transfer(dst, amount);
    }
}
