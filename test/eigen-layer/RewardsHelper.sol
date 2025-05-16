// SPDX-License-Identifier: BUSL-1.1
// Non-production use
pragma solidity ^0.8;

import "forge-std/Test.sol";
import {IRewardsCoordinator} from
    "@src/interfaces/eigen-layer/IRewardsCoordinator.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {ERC20} from "@src/helpers/ERC20.sol";

// Copied from https://github.com/Layr-Labs/eigenlayer-contracts/blob/c27424db55b336e6167fb3e3a05c0dc306c55fa5/src/test/unit/RewardsCoordinatorUnit.t.sol#L3558
contract RewardsHelper is Test {
    Vm cheats = vm;

    address rewardsUpdater;
    IRewardsCoordinator rewardsCoordinator;

    IERC20 erc20 = IERC20(address(new ERC20("test", "TEST", 18)));
    bytes mockTokenBytecode = address(erc20).code;
    uint32 prevRootCalculationEndTimestamp;

    // Hardcoded address in root.json
    address public earner = 0xF2288D736d27C1584Ebf7be5f52f9E4d47251AeE;
    // tmp storage
    bytes32 merkleRoot;
    uint32 earnerIndex;
    bytes earnerTreeProof;
    address proofEarner;
    bytes32 earnerTokenRoot;

    constructor(address _rewardsCoordinator) {
        rewardsCoordinator = IRewardsCoordinator(_rewardsCoordinator);
        rewardsUpdater = rewardsCoordinator.rewardsUpdater();
    }

    function parseProofData(string memory filePath)
        public
        returns (IRewardsCoordinator.RewardsMerkleClaim memory)
    {
        cheats.readFile(filePath);

        string memory claimProofData = cheats.readFile(filePath);

        // Parse RewardsMerkleClaim
        merkleRoot =
            abi.decode(stdJson.parseRaw(claimProofData, ".Root"), (bytes32));
        earnerIndex = abi.decode(
            stdJson.parseRaw(claimProofData, ".EarnerIndex"), (uint32)
        );
        earnerTreeProof = abi.decode(
            stdJson.parseRaw(claimProofData, ".EarnerTreeProof"), (bytes)
        );
        proofEarner = stdJson.readAddress(claimProofData, ".EarnerLeaf.Earner");
        require(
            earner == proofEarner, "earner in test and json file do not match"
        );
        earnerTokenRoot = abi.decode(
            stdJson.parseRaw(claimProofData, ".EarnerLeaf.EarnerTokenRoot"),
            (bytes32)
        );
        uint256 numTokenLeaves =
            stdJson.readUint(claimProofData, ".TokenLeavesNum");
        uint256 numTokenTreeProofs =
            stdJson.readUint(claimProofData, ".TokenTreeProofsNum");

        IRewardsCoordinator.TokenTreeMerkleLeaf[] memory tokenLeaves =
            new IRewardsCoordinator.TokenTreeMerkleLeaf[](numTokenLeaves);
        uint32[] memory tokenIndices = new uint32[](numTokenLeaves);
        for (uint256 i = 0; i < numTokenLeaves; ++i) {
            string memory tokenKey =
                string.concat(".TokenLeaves[", cheats.toString(i), "].Token");
            string memory amountKey = string.concat(
                ".TokenLeaves[", cheats.toString(i), "].CumulativeEarnings"
            );
            string memory leafIndicesKey =
                string.concat(".LeafIndices[", cheats.toString(i), "]");

            IERC20 token = IERC20(stdJson.readAddress(claimProofData, tokenKey));
            uint256 cumulativeEarnings =
                stdJson.readUint(claimProofData, amountKey);
            tokenLeaves[i] = IRewardsCoordinator.TokenTreeMerkleLeaf({
                token: address(token),
                cumulativeEarnings: cumulativeEarnings
            });
            tokenIndices[i] =
                uint32(stdJson.readUint(claimProofData, leafIndicesKey));

            /// DeployCode ERC20 to Token Address
            // deployCodeTo("ERC20PresetFixedSupply.sol", address(tokenLeaves[i].token));
            _setAddressAsERC20(address(token), cumulativeEarnings);
        }
        bytes[] memory tokenTreeProofs = new bytes[](numTokenTreeProofs);
        for (uint256 i = 0; i < numTokenTreeProofs; ++i) {
            string memory tokenTreeProofKey =
                string.concat(".TokenTreeProofs[", cheats.toString(i), "]");
            tokenTreeProofs[i] = abi.decode(
                stdJson.parseRaw(claimProofData, tokenTreeProofKey), (bytes)
            );
        }

        uint32 rootCalculationEndTimestamp = uint32(block.timestamp);
        uint32 activatedAt =
            uint32(block.timestamp) + rewardsCoordinator.activationDelay();
        prevRootCalculationEndTimestamp = rootCalculationEndTimestamp;
        cheats.warp(activatedAt);

        uint32 rootIndex =
            uint32(rewardsCoordinator.getDistributionRootsLength());

        cheats.prank(rewardsUpdater);
        rewardsCoordinator.submitRoot(
            merkleRoot, prevRootCalculationEndTimestamp
        );

        IRewardsCoordinator.RewardsMerkleClaim memory newClaim =
        IRewardsCoordinator.RewardsMerkleClaim({
            rootIndex: rootIndex,
            earnerIndex: earnerIndex,
            earnerTreeProof: earnerTreeProof,
            earnerLeaf: IRewardsCoordinator.EarnerTreeMerkleLeaf({
                earner: earner,
                earnerTokenRoot: earnerTokenRoot
            }),
            tokenIndices: tokenIndices,
            tokenTreeProofs: tokenTreeProofs,
            tokenLeaves: tokenLeaves
        });

        return newClaim;
    }

    function _setAddressAsERC20(address randAddress, uint256 mintAmount)
        internal
    {
        cheats.etch(randAddress, mockTokenBytecode);
        ERC20(randAddress).mint(address(rewardsCoordinator), mintAmount);
    }
}
