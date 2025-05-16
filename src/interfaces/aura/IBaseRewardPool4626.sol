// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IBaseRewardPool4626 {
    /// @notice Returns amount of shares staked in this contract
    function balanceOf(address) external view returns (uint256);
    function earned(address account) external view returns (uint256);
    function deposit(uint256 amount, address receiver)
        external
        returns (uint256);
    function getReward() external;
    /// @notice Withdraw shares from Aura
    /// @param amount Amount of shares to withdraw
    /// @param claim True to claim rewards
    function withdrawAndUnwrap(uint256 amount, bool claim)
        external
        returns (bool);
}
