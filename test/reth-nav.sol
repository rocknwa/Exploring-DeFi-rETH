// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

// =================================================================================================
// Imports
// =================================================================================================

import {Test, console} from "forge-std/Test.sol"; // Import Test and console utilities from Foundry's standard library for testing.
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol"; // Import the IRETH interface for interacting with the Rocket Pool rETH token contract.
import {RETH} from "@src/helpers/Constants.sol"; // Import the RETH constant, which likely holds the address of the rETH token.
import {RethNav} from "@src/RethNav.sol"; // Import the RethNav contract, which is the contract under test.

// =================================================================================================
// Test Contract Definition
// =================================================================================================

// Command to run this specific test file using Foundry:
// forge test --fork-url $FORK_URL --match-path test/reth-nav.sol -vv

/**
 * @title RethNavTest
 * @notice Test suite for the RethNav contract.
 * @dev This contract uses Foundry for testing and requires a forked mainnet environment
 * to interact with live Rocket Pool and Chainlink contracts.
 */
contract RethNavTest is Test {
    // =============================================================================================
    // State Variables
    // =============================================================================================

    IRETH internal reth = IRETH(RETH); // Instance of the IRETH contract, initialized with the RETH address. Used to interact with rETH.
    RethNav internal nav; // Instance of the RethNav contract that will be tested.

    // =============================================================================================
    // Setup Function
    // =============================================================================================

    /**
     * @notice Sets up the test environment before each test case.
     * @dev This function is called by Foundry before running each test function.
     * It deploys a new instance of the RethNav contract.
     */
    function setUp() public {
        nav = new RethNav(); // Deploy a new RethNav contract instance.
    }

    // =============================================================================================
    // Test Functions
    // =============================================================================================

    /**
     * @notice Tests the getExchangeRate and getExchangeRateFromChainlink functions of the RethNav contract.
     * @dev This test verifies that:
     * 1. The NAV (Net Asset Value) rate returned by `nav.getExchangeRate()` (from Rocket Pool) is greater than zero.
     * 2. The exchange rate returned by `nav.getExchangeRateFromChainlink()` is greater than zero.
     * It logs both rates to the console for inspection.
     */
    function test_nav() public view {
        // Test the getExchangeRate function which should return the amount of ETH backing 1 rETH from Rocket Pool's contracts.
        uint256 navRate = nav.getExchangeRate();
        console.log("ETH / rETH rate from Rocket Pool: %e", navRate); // Log the rate retrieved directly from Rocket Pool.
        assertGt(navRate, 0, "Rocket Pool NAV rate should be greater than zero"); // Assert that the NAV rate is positive.

        // Test the getExchangeRateFromChainlink function which should return the ETH/rETH exchange rate from Chainlink.
        uint256 chainlinkRate = nav.getExchangeRateFromChainlink();
        console.log("ETH / rETH rate from Chainlink: %e", chainlinkRate); // Log the rate retrieved from Chainlink.
        assertGt(chainlinkRate, 0, "Chainlink exchange rate should be greater than zero"); // Assert that the Chainlink rate is positive.
    }
}