// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface IRewardsCoordinator {
    struct StrategyAndMultiplier {
        address strategy;
        uint96 multiplier;
    }

    struct RewardsSubmission {
        StrategyAndMultiplier[] strategiesAndMultipliers;
        address token;
        uint256 amount;
        uint32 startTimestamp;
        uint32 duration;
    }

    struct DistributionRoot {
        bytes32 root;
        uint32 rewardsCalculationEndTimestamp;
        uint32 activatedAt;
        bool disabled;
    }

    struct EarnerTreeMerkleLeaf {
        address earner;
        bytes32 earnerTokenRoot;
    }

    struct TokenTreeMerkleLeaf {
        address token;
        uint256 cumulativeEarnings;
    }

    struct RewardsMerkleClaim {
        uint32 rootIndex;
        uint32 earnerIndex;
        bytes earnerTreeProof;
        EarnerTreeMerkleLeaf earnerLeaf;
        uint32[] tokenIndices;
        bytes[] tokenTreeProofs;
        TokenTreeMerkleLeaf[] tokenLeaves;
    }

    function rewardsUpdater() external view returns (address);
    function CALCULATION_INTERVAL_SECONDS() external view returns (uint32);
    function MAX_REWARDS_DURATION() external view returns (uint32);
    function MAX_RETROACTIVE_LENGTH() external view returns (uint32);
    function MAX_FUTURE_LENGTH() external view returns (uint32);
    function GENESIS_REWARDS_TIMESTAMP() external view returns (uint32);
    function activationDelay() external view returns (uint32);
    function claimerFor(address earner) external view returns (address);
    function cumulativeClaimed(address claimer, address token)
        external
        view
        returns (uint256);
    function globalOperatorCommissionBips() external view returns (uint16);
    function operatorCommissionBips(address operator, address avs)
        external
        view
        returns (uint16);
    function calculateEarnerLeafHash(EarnerTreeMerkleLeaf calldata leaf)
        external
        pure
        returns (bytes32);
    function calculateTokenLeafHash(TokenTreeMerkleLeaf calldata leaf)
        external
        pure
        returns (bytes32);
    function checkClaim(RewardsMerkleClaim calldata claim)
        external
        view
        returns (bool);
    function currRewardsCalculationEndTimestamp()
        external
        view
        returns (uint32);
    function getDistributionRootsLength() external view returns (uint256);
    function getDistributionRootAtIndex(uint256 index)
        external
        view
        returns (DistributionRoot memory);
    function getCurrentDistributionRoot()
        external
        view
        returns (DistributionRoot memory);
    function getCurrentClaimableDistributionRoot()
        external
        view
        returns (DistributionRoot memory);
    function getRootIndexFromHash(bytes32 rootHash)
        external
        view
        returns (uint32);

    function createAVSRewardsSubmission(
        RewardsSubmission[] calldata rewardsSubmissions
    ) external;
    function createRewardsForAllSubmission(
        RewardsSubmission[] calldata rewardsSubmission
    ) external;
    function createRewardsForAllEarners(
        RewardsSubmission[] calldata rewardsSubmissions
    ) external;
    function processClaim(RewardsMerkleClaim calldata claim, address recipient)
        external;
    function submitRoot(bytes32 root, uint32 rewardsCalculationEndTimestamp)
        external;
    function disableRoot(uint32 rootIndex) external;
    function setClaimerFor(address claimer) external;
    function setActivationDelay(uint32 _activationDelay) external;
    function setGlobalOperatorCommission(uint16 _globalCommissionBips)
        external;
    function setRewardsUpdater(address _rewardsUpdater) external;
    function setRewardsForAllSubmitter(address _submitter, bool _newValue)
        external;
}
