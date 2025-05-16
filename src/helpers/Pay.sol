// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Pay
/// @notice Provides a simple function to send ETH to a specified address.
/// @dev Uses low-level `call` for transferring ETH.
contract Pay {
    /// @notice Sends ETH to a specified address.
    /// @param to The address to which ETH will be sent.
    /// @param amount The amount of ETH (in wei) to send.
    /// @dev Reverts if the recipient address is zero or if the transfer fails.
    function pay(address to, uint256 amount) external {
        require(to != address(0), "to = 0 addr");
        (bool ok,) = to.call{value: amount}("");
        require(ok, "pay failed");
    }
}
