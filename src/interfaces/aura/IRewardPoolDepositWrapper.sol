// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IVault} from "../balancer/IVault.sol";

interface IRewardPoolDepositWrapper {
    /// @notice Deposits a token into Balancer before depositing into Aura reward pool.
    ///         Requires sender to approve this contract before calling.
    /// @param rewardPool Address of Aura reward pool
    /// @param inputToken Address of token to add as liquidity to Balancer
    /// @param inputAmount Amount of token to add as liquidity to Balancer
    /// @param balancerPoolId Id of Balancer pool to add liquidity to
    /// @param request Request to foward to Balancer pool
    function depositSingle(
        address rewardPool,
        address inputToken,
        uint256 inputAmount,
        bytes32 balancerPoolId,
        IVault.JoinPoolRequest memory request
    ) external;
}
