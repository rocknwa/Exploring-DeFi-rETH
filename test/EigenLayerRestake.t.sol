// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title EigenLayerTest
/// @notice Test suite for EigenLayerRestake contract functionality
/// @dev Uses Forge testing framework to test deposit, delegation, undelegation, and transfer operations
import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {IStrategyManager} from "@src/interfaces/eigen-layer/IStrategyManager.sol";
import {IStrategy} from "@src/interfaces/eigen-layer/IStrategy.sol";
import {IDelegationManager} from "@src/interfaces/eigen-layer/IDelegationManager.sol";
import {IRewardsCoordinator} from "@src/interfaces/eigen-layer/IRewardsCoordinator.sol";
import {RewardsHelper} from "./eigen-layer/RewardsHelper.sol";
import {
    RETH,
    EIGEN_LAYER_STRATEGY_MANAGER,
    EIGEN_LAYER_STRATEGY_RETH,
    EIGEN_LAYER_DELEGATION_MANAGER,
    EIGEN_LAYER_REWARDS_COORDINATOR,
    EIGEN_LAYER_OPERATOR
} from "@src/helpers/Constants.sol";
import {EigenLayerRestake} from "@src/EigenLayerRestake.sol";
import {max} from "@src/helpers/Util.sol";

// forge test --fork-url $FORK_URL --match-path test/EigenLayerRestake.t.sol -vvv

contract EigenLayerTest is Test {
    IERC20 constant reth = IERC20(RETH);
    IStrategyManager constant strategyManager =
        IStrategyManager(EIGEN_LAYER_STRATEGY_MANAGER);
    IStrategy constant strategy = IStrategy(EIGEN_LAYER_STRATEGY_RETH);
    IDelegationManager constant delegationManager =
        IDelegationManager(EIGEN_LAYER_DELEGATION_MANAGER);

    uint256 constant RETH_AMOUNT = 1e18;

    EigenLayerRestake restake;

    function setUp() public {
        deal(RETH, address(this), RETH_AMOUNT);
        reth.approve(address(strategyManager), type(uint256).max);

        restake = new EigenLayerRestake();
        reth.approve(address(restake), type(uint256).max);
    }

    function test_deposit() public {
        // Test auth
        vm.expectRevert();
        vm.prank(address(1));
        restake.deposit(RETH_AMOUNT);

        uint256 shares = restake.deposit(RETH_AMOUNT);
        console.log("shares %e", shares);

        assertGt(shares, 0);
        assertEq(
            shares,
            strategyManager.stakerDepositShares(
                address(restake), address(strategy)
            )
        );
        assertEq(reth.balanceOf(address(restake)), 0);
        assertEq(reth.balanceOf(address(this)), 0);
    }

    function test_delegate() public {
        restake.deposit(RETH_AMOUNT);

        // Test auth
        vm.expectRevert();
        vm.prank(address(1));
        restake.delegate(EIGEN_LAYER_OPERATOR);

        restake.delegate(EIGEN_LAYER_OPERATOR);
        assertEq(
            delegationManager.delegatedTo(address(restake)),
            EIGEN_LAYER_OPERATOR
        );
    }

    function test_undelegate() public {
        restake.deposit(RETH_AMOUNT);
        restake.delegate(EIGEN_LAYER_OPERATOR);

        // Test auth
        vm.expectRevert();
        vm.prank(address(1));
        restake.undelegate();

        restake.undelegate();
        assertEq(delegationManager.delegatedTo(address(restake)), address(0));
    }

    function test_withdraw() public {
        uint256 shares = restake.deposit(RETH_AMOUNT);
        restake.delegate(EIGEN_LAYER_OPERATOR);

        uint256 b0 = block.number;
        restake.undelegate();

        uint256 protocolDelay = delegationManager.minWithdrawalDelayBlocks();
        console.log("Protocol delay:", protocolDelay);

        vm.roll(b0 + protocolDelay + 1);

        // Test auth
        vm.expectRevert();
        vm.prank(address(1));
        restake.withdraw(EIGEN_LAYER_OPERATOR, shares, uint32(b0));

        restake.withdraw(EIGEN_LAYER_OPERATOR, shares, uint32(b0));

        uint256 rethBal = reth.balanceOf(address(restake));
        console.log("RETH %e", rethBal);
        assertGt(rethBal, 0);
    }

    function test_transfer() public {
        // Test auth
        vm.expectRevert();
        vm.prank(address(1));
        restake.transfer(RETH, address(1));

        restake.transfer(RETH, address(1));
    }
}

/// @title EigenLayerRewardsTest
/// @notice Test suite for claiming rewards in EigenLayerRestake
/// @dev Tests reward claiming using a Merkle proof with RewardsHelper
contract EigenLayerRewardsTest is Test {
    /// @notice EigenLayer RewardsCoordinator interface
    IRewardsCoordinator internal constant rewardsCoordinator = IRewardsCoordinator(EIGEN_LAYER_REWARDS_COORDINATOR);

    /// @notice Instance of RewardsHelper contract
    RewardsHelper internal helper;
    /// @notice Instance of EigenLayerRestake contract
    EigenLayerRestake internal restake;

    /// @notice Sets up the test environment
    /// @dev Deploys RewardsHelper, configures EigenLayerRestake at earner address
    function setUp() public {
        // Deploy RewardsHelper with RewardsCoordinator address
        helper = new RewardsHelper(address(rewardsCoordinator));

        // Deploy EigenLayerRestake
        restake = new EigenLayerRestake();

        // Set EigenLayerRestake code at the earner address (hardcoded in root.json)
        address earner = helper.earner();
        vm.etch(earner, address(restake).code);
        restake = EigenLayerRestake(earner);
    }

    /// @notice Tests claiming rewards using a Merkle proof
    /// @dev Verifies reward token balances after claiming
    function test_claimRewards() public {
        // Parse Merkle proof data from JSON file
        IRewardsCoordinator.RewardsMerkleClaim memory claim = helper.parseProofData("test/eigen-layer/root.json");

        // Skip activation delay to allow claiming
        skip(rewardsCoordinator.activationDelay() + 1);

        // Claim rewards
        restake.claimRewards(claim);

        // Verify reward token balances
        for (uint256 i = 0; i < claim.tokenLeaves.length; i++) {
            IERC20 token = IERC20(claim.tokenLeaves[i].token);
            uint256 bal = token.balanceOf(address(restake));
            console.log("Reward token: ", address(token));
            console.log("Reward balance: %e", bal);
            assertGt(bal, 0, "Reward token balance should be greater than 0");
        }
    }
}