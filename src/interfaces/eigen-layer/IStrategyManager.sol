// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IStrategyManager {
    // Removed duplicate definition of stakerStrategyShares
    // Removed duplicate definition of depositIntoStrategy

    // Removed duplicate definition of isRegisteredStrategy
    function isStrategy(address strategy) external view returns (bool);
    function strategyWithdrawalDelayBlocks(address strategy) external view returns (uint256);
    function depositIntoStrategy(address strategy, address token, uint256 amount) external returns (uint256);
    function stakerStrategyShares(address user, address strategy) external view returns (uint256);
    function isRegisteredStrategy(address strategy) external view returns (bool);
    function paused() external view returns (bool);



}
