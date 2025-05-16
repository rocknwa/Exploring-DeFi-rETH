// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/// @title Proxy
/// @notice Provides a mechanism to execute delegated calls and manage ownership.
/// @dev This contract uses a transient storage slot for temporary target storage
contract Proxy {
    /// @dev Storage slot for the owner address, using a unique deterministic hash to avoid conflicts.
    bytes32 private constant OWNER_SLOT =
        0x02016836a56b71f0d02689e69e326f4f4c1b9057164ef592671cf0d37c8040bf;

    /// @dev Transient storage slot for the target address during execution.
    bytes32 private constant TRANSIENT_TARGET_SLOT = 0;

    /// @notice Ensures that only the owner can call the function.
    modifier auth() {
        require(msg.sender == owner(), "not authorized");
        _;
    }

    /// @notice Temporarily sets the target address for delegate calls.
    /// @param _target The address of the target contract.
    /// @dev The target is stored in a transient storage slot and cleared after execution.
    modifier set(address _target) {
        assembly {
            tstore(TRANSIENT_TARGET_SLOT, _target)
        }
        _;
        assembly {
            tstore(TRANSIENT_TARGET_SLOT, 0)
        }
    }

    /// @notice Initializes the proxy with the owner address.
    /// @param _owner The address of the contract owner.
    constructor(address _owner) {
        assembly {
            sstore(OWNER_SLOT, _owner)
        }
    }

    /// @notice Allows the contract to receive Ether.
    receive() external payable {}

    /// @notice Fallback function to handle delegate calls.
    /// @param data The calldata for the delegate call.
    /// @return res The return data from the delegate call.
    /// @dev Requires a valid target to be set in the transient storage slot.
    fallback(bytes calldata data) external payable returns (bytes memory res) {
        address addr = target();
        require(addr != address(0), "target not set");

        bool ok;
        (ok, res) = addr.delegatecall(data);
        require(ok, "fallback failed");
    }

    /// @notice Gets the address of the contract owner.
    /// @return addr The address of the owner.
    function owner() public view returns (address addr) {
        assembly {
            addr := sload(OWNER_SLOT)
        }
    }

    /// @notice Gets the current target address for delegate calls.
    /// @return addr The address of the target contract.
    function target() private view returns (address addr) {
        assembly {
            addr := tload(TRANSIENT_TARGET_SLOT)
        }
    }

    /// @notice Executes a delegate call to a target contract.
    /// @param _target The address of the target contract.
    /// @param data The calldata to be passed to the delegate call.
    /// @return res The return data from the delegate call.
    /// @dev Can only be called by the owner and requires a valid target to be set.
    function execute(address _target, bytes calldata data)
        external
        payable
        auth
        set(_target)
        returns (bytes memory res)
    {
        bool ok;
        (ok, res) = _target.delegatecall(data);
        require(ok, "delegatecall failed");
    }
}
