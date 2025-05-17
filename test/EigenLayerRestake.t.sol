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
    /// @notice rETH token interface
    IERC20 internal constant reth = IERC20(RETH);
    /// @notice EigenLayer StrategyManager interface
    IStrategyManager internal constant strategyManager = IStrategyManager(EIGEN_LAYER_STRATEGY_MANAGER);
    /// @notice EigenLayer rETH strategy interface
    IStrategy internal constant strategy = IStrategy(EIGEN_LAYER_STRATEGY_RETH);
    /// @notice EigenLayer DelegationManager interface
    IDelegationManager internal constant delegationManager = IDelegationManager(EIGEN_LAYER_DELEGATION_MANAGER);

    /// @notice Amount of rETH used for testing (1 rETH)
    uint256 internal constant RETH_AMOUNT = 1e18;

    /// @notice Instance of EigenLayerRestake contract
    EigenLayerRestake internal restake;

    /// @notice Sets up the test environment
    /// @dev Funds the test contract with rETH, deploys EigenLayerRestake, and sets approvals
    function setUp() public {
        // Fund this contract with 1 rETH
        deal(RETH, address(this), RETH_AMOUNT);

        // Approve StrategyManager to spend rETH
        reth.approve(address(strategyManager), type(uint256).max);

        // Deploy EigenLayerRestake contract
        restake = new EigenLayerRestake();

        // Approve EigenLayerRestake to spend rETH
        reth.approve(address(restake), type(uint256).max);
    }

    /// @notice Tests depositing rETH into EigenLayerRestake
    /// @dev Verifies authorization, share issuance, and token balances
    function test_deposit() public {
        // Test unauthorized deposit (should revert)
        vm.expectRevert();
        vm.prank(address(1));
        restake.deposit(RETH_AMOUNT);

        // Perform authorized deposit
        uint256 shares = restake.deposit(RETH_AMOUNT);
        console.log("shares %e", shares);

        // Verify shares were issued
        assertGt(shares, 0, "Shares should be greater than 0");

        // Verify token balances
        assertEq(reth.balanceOf(address(restake)), 0, "Restake contract rETH balance should be 0");
        assertEq(reth.balanceOf(address(this)), 0, "Test contract rETH balance should be 0");
    }

    /// @notice Tests delegating to an operator in EigenLayer
    /// @dev Verifies authorization and delegation status
    function test_delegate() public {
        // Deposit rETH first
        restake.deposit(RETH_AMOUNT);

        // Test unauthorized delegation (should revert)
        vm.expectRevert();
        vm.prank(address(1));
        restake.delegate(EIGEN_LAYER_OPERATOR);

        // Perform authorized delegation
        restake.delegate(EIGEN_LAYER_OPERATOR);

        // Verify delegation to the operator
        assertEq(
            delegationManager.delegatedTo(address(restake)),
            EIGEN_LAYER_OPERATOR,
            "Delegation should be set to operator"
        );
    }

    /// @notice Tests undelegating from an operator in EigenLayer
    /// @dev Verifies authorization and undelegation status
    function test_undelegate() public {
        // Deposit and delegate first
        restake.deposit(RETH_AMOUNT);
        restake.delegate(EIGEN_LAYER_OPERATOR);

        // Test unauthorized undelegation (should revert)
        vm.expectRevert();
        vm.prank(address(1));
        restake.undelegate();

        // Perform authorized undelegation
        restake.undelegate();

        // Verify no operator is delegated
        assertEq(
            delegationManager.delegatedTo(address(restake)),
            address(0),
            "Delegation should be unset"
        );
    }

    /// @notice Tests transferring rETH from EigenLayerRestake
    /// @dev Verifies authorization for transfer
    function test_transfer() public {
        // Test unauthorized transfer (should revert)
        vm.expectRevert();
        vm.prank(address(1));
        restake.transfer(RETH, address(1));

        // Perform authorized transfer
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