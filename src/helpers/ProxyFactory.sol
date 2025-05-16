// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import {Proxy} from "./Proxy.sol";

/// @title ProxyFactory
/// @notice A contract to deploy new Proxy instances.
/// @dev The factory creates a new proxy for each caller and emits an event with the proxy address.
contract ProxyFactory {
    /// @notice Emitted when a new Proxy contract is deployed.
    /// @param owner The address of the owner of the newly deployed Proxy contract.
    /// @param proxy The address of the newly deployed Proxy contract.
    event Deploy(address indexed owner, address proxy);

    /// @notice Deploys a new Proxy contract and sets the caller as the owner.
    /// @return proxy The address of the newly deployed Proxy contract.
    /// @dev This function creates a new instance of the Proxy contract and emits a Deploy event.
    function deploy() external returns (address proxy) {
        proxy = address(new Proxy(msg.sender));
        emit Deploy(msg.sender, proxy);
    }
}
