// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IMetaStablePool {
    function getPoolId() external view returns (bytes32);
}
