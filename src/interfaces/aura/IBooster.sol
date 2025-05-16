// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

interface IBooster {
    struct PoolInfo {
        address lpToken;
        address token;
        address gauge;
        address crvRewards;
        address stash;
        bool shutdown;
    }

    function poolInfo(uint256 pid) external view returns (PoolInfo memory);
    function deposit(uint256 pid, uint256 amount, bool stake)
        external
        returns (bool);
}

import {IVault} from "../balancer/IVault.sol";

interface IRewardPoolDepositWrapper {
    function depositSingle(
        address rewardPool,
        address inputToken,
        uint256 inputAmount,
        bytes32 balancerPoolId,
        IVault.JoinPoolRequest memory request
    ) external;
}

interface BaseRewardPool4626 {
    function balanceOf(address) external view returns (uint256);
    function getReward() external;
    function withdrawAndUnwrap(uint256 amount, bool claim)
        external
        returns (bool);
}
