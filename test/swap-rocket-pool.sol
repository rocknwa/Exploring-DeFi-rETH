// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title RocketPoolTestSuite
/// @notice Test suite for SwapRocketPool contract functionality
/// @dev Uses Forge testing framework to test Rocket Pool view functions and swaps
import {Test, console} from "forge-std/Test.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {IRocketStorage} from "@src/interfaces/rocket-pool/IRocketStorage.sol";
import {IRocketDepositPool} from "@src/interfaces/rocket-pool/IRocketDepositPool.sol";
import {IRocketDAOProtocolSettingsDeposit} from "@src/interfaces/rocket-pool/IRocketDAOProtocolSettingsDeposit.sol";
import {
    RETH,
    ROCKET_STORAGE,
    ROCKET_DEPOSIT_POOL,
    ROCKET_DAO_PROTOCOL_SETTINGS_DEPOSIT
} from "@src/helpers/Constants.sol";
import {SwapRocketPool} from "@src/SwapRocketPool.sol";

// forge test --fork-url $FORK_URL --match-path test/swap-rocket-pool.sol -vvv

/// @dev Base value for calculations (1e18 = 1 ETH or 1 rETH)
uint256 constant CALC_BASE = 1e18;

/// @title RocketPoolTestBase
/// @notice Base contract for Rocket Pool tests
/// @dev Provides common setup and utility functions for derived test contracts
contract RocketPoolTestBase is Test {
    /// @notice rETH token interface
    IRETH internal constant reth = IRETH(RETH);
    /// @notice Rocket Pool storage interface
    IRocketStorage internal constant rStorage = IRocketStorage(ROCKET_STORAGE);
    /// @notice Rocket Pool deposit pool interface
    IRocketDepositPool internal constant depositPool = IRocketDepositPool(ROCKET_DEPOSIT_POOL);
    /// @notice Rocket Pool protocol settings interface
    IRocketDAOProtocolSettingsDeposit internal constant protocolSettings = IRocketDAOProtocolSettingsDeposit(ROCKET_DAO_PROTOCOL_SETTINGS_DEPOSIT);

    /// @notice Instance of SwapRocketPool contract
    SwapRocketPool internal swap;

    /// @notice Sets up the test environment
    /// @dev Deploys SwapRocketPool contract
    function setUp() public virtual {
        swap = new SwapRocketPool();
    }

    /// @notice Computes storage key for last deposit block
    /// @param user User address
    /// @return Storage key as bytes32
    function getLastDepositBlockKey(address user) public pure returns (bytes32) {
        return keccak256(abi.encodePacked("user.deposit.block", user));
    }

    /// @notice Retrieves last deposit block for a user
    /// @param user User address
    /// @return Block number of last deposit
    function getLastDepositBlock(address user) public view returns (uint256) {
        return rStorage.getUint(getLastDepositBlockKey(user));
    }

    /// @notice Retrieves deposit delay from Rocket Pool storage
    /// @return Deposit delay in blocks
    function getDepositDelay() public view returns (uint256) {
        return rStorage.getUint(
            keccak256(
                abi.encodePacked(
                    keccak256("dao.protocol.setting.network"),
                    "network.reth.deposit.delay"
                )
            )
        );
    }
}

/// @title RocketPoolViewTest
/// @notice Tests for SwapRocketPool view functions
/// @dev Verifies calculations and availability checks
contract RocketPoolViewTest is RocketPoolTestBase {
    /// @notice Tests ETH to rETH conversion calculation
    /// @dev Verifies rETH amount and fee calculation
    function test_calcEthToReth() public view {
        // Get current rETH/ETH exchange rate
        uint256 rate = reth.getExchangeRate();
        console.log("Exchange rate: 1e18 rETH = %e ETH", rate);

        // Calculate expected fee
        uint256 depositFee = protocolSettings.getDepositFee();
        uint256 ethAmount = 1e18;
        uint256 ethFee = ethAmount * depositFee / CALC_BASE;

        // Call calcEthToReth to get rETH amount and fee
        (uint256 rEthAmount, uint256 fee) = swap.calcEthToReth(ethAmount);

        // Log results for debugging
        console.log("rETH amount: %e", rEthAmount);
        console.log("Deposit fee: %e ETH", fee);

        // Verify fee and rETH amount
        assertEq(fee, ethFee, "Fee should match calculated fee");
        assertEq(
            rEthAmount,
            reth.getRethValue(ethAmount - fee),
            "rETH amount should match expected value"
        );
    }

    /// @notice Tests rETH to ETH conversion calculation
    /// @dev Verifies ETH amount calculation
    function test_calcRethToEth() public view {
        uint256 rEthAmount = 1e18;
        uint256 ethAmount = swap.calcRethToEth(rEthAmount);
        console.log("ETH amount: %e", ethAmount);
        assertEq(
            ethAmount,
            reth.getEthValue(rEthAmount),
            "ETH amount should match expected value"
        );
    }

    /// @notice Tests deposit availability check
    /// @dev Verifies deposit enabled status and maximum deposit amount
    function test_getAvailability() public view {
        bool enabled = protocolSettings.getDepositEnabled();
        uint256 maxDeposit = depositPool.getMaximumDepositAmount();

        // Log results for debugging
        console.log("Deposit enabled:", enabled);
        console.log("Max deposit: %e", maxDeposit);

        // Call getAvailability to check status
        (bool ok, uint256 max) = swap.getAvailability();

        // Verify availability and maximum deposit
        assertEq(ok, enabled, "Availability should match protocol settings");
        assertEq(max, maxDeposit, "Max deposit should match deposit pool");
    }

    /// @notice Tests deposit delay retrieval
    /// @dev Verifies deposit delay matches storage value
    function test_getDepositDelay() public view {
        assertEq(
            swap.getDepositDelay(),
            getDepositDelay(),
            "Deposit delay should match storage value"
        );
    }

    /// @notice Tests last deposit block retrieval
    /// @dev Simulates storage to verify block number
    function test_getLastDepositBlock() public {
        // Simulate storage slot for last deposit block
        bytes32 key = keccak256(
            abi.encode(getLastDepositBlockKey(address(this)), uint256(2))
        );
        uint256 blockNum = block.number;
        vm.store(address(rStorage), key, bytes32(blockNum));

        // Verify retrieved block number
        assertEq(
            swap.getLastDepositBlock(address(this)),
            blockNum,
            "Last deposit block should match stored value"
        );
    }
}

/// @title RocketPoolSwapTest
/// @notice Tests for SwapRocketPool swap functions
/// @dev Tests ETH to rETH and rETH to ETH swaps
contract RocketPoolSwapTest is RocketPoolTestBase {
    /// @dev Flag to enable mocked calls (true) or use live contract states (false)
    bool constant MOCK_CALLS = false;

    /// @notice Enables receiving ETH
    /// @dev Required for Rocket Pool ETH withdrawals
    receive() external payable {}

    /// @notice Sets up the test environment
    /// @dev Configures mocks if MOCK_CALLS is true and logs initial state
    function setUp() public override {
        super.setUp();

        if (MOCK_CALLS) {
            // Mock deposit enabled status
            vm.mockCall(
                address(protocolSettings),
                abi.encodeCall(IRocketDAOProtocolSettingsDeposit.getDepositEnabled, ()),
                abi.encode(true)
            );
            // Mock maximum deposit amount (100 ETH)
            vm.mockCall(
                address(depositPool),
                abi.encodeCall(IRocketDepositPool.getMaximumDepositAmount, ()),
                abi.encode(uint256(100 * 1e18))
            );
            // Mock exchange rate (1:1)
            vm.mockCall(
                address(reth),
                abi.encodeCall(IRETH.getExchangeRate, ()),
                abi.encode(uint256(1e18))
            );
        }

        // Log initial state for debugging
        console.log("Deposit enabled:", protocolSettings.getDepositEnabled());
        console.log("Dax deposit: %e", depositPool.getMaximumDepositAmount());
        console.log("Exchange rate: 1e18 rETH = %e ETH", reth.getExchangeRate());
    }

    /// @notice Tests swapping ETH to rETH
    /// @dev Verifies rETH balance after swap
    function test_swapEthToReth() public {
        console.log("Deposit enabled:", protocolSettings.getDepositEnabled());
        uint256 ethAmount = 1e18;

        // Perform ETH to rETH swap
        swap.swapEthToReth{value: ethAmount}();

        // Log rETH balance for debugging
        uint256 rEthBal = reth.balanceOf(address(swap));
        console.log("rETH balance: %e", rEthBal);

        // Verify rETH was received
        assertGt(rEthBal, 0, "rETH balance should be greater than 0");
    }

    /// @notice Tests swapping rETH to ETH
    /// @dev Verifies ETH balance and token burns after swap
    function test_swapRethToEth() public {
        // Fund Rocket Pool with 10 ETH for liquidity
        (bool ok,) = RETH.call{value: 10 * 1e18}("");
        require(ok, "Send ETH failed");

        // Deposit 1 ETH to receive rETH
        depositPool.deposit{value: 1e18}();

        // Log initial rETH balance
        uint256 rEthAmount = reth.balanceOf(address(this));
        console.log("rETH balance: %e", rEthAmount);

        // Approve SwapRocketPool to spend rETH
        reth.approve(address(swap), rEthAmount);

        // Record ETH balance before swap
        uint256 ethBalBefore = address(swap).balance;

        // Perform rETH to ETH swap
        swap.swapRethToEth(rEthAmount);

        // Record ETH balance after swap
        uint256 ethBalAfter = address(swap).balance;

        // Verify token balances and ETH received
        assertEq(reth.balanceOf(address(this)), 0, "Test contract rETH balance should be 0");
        assertEq(reth.balanceOf(address(swap)), 0, "Swap contract rETH balance should be 0");
        assertGt(ethBalAfter, ethBalBefore, "ETH balance should increase");

        // Log ETH received for debugging
        uint256 ethDelta = ethBalAfter - ethBalBefore;
        console.log("ETH received: %e", ethDelta);

        // Verify ETH received based on exchange rate
        uint256 rate = reth.getExchangeRate();
        if (rate >= 1e18) {
            assertGe(ethDelta, rEthAmount, "ETH received should be >= rETH amount");
        } else {
            assertGe(rEthAmount, ethDelta, "rETH amount should be >= ETH received");
        }
    }
}