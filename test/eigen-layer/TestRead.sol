// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

// =================================================================================================
// Imports
// =================================================================================================

import "forge-std/Test.sol"; // Import Test utilities from Foundry's standard library for testing.

// =================================================================================================
// Test Contract Definition
// =================================================================================================

/**
 * @title TestJson
 * @notice A simple test contract to demonstrate reading a JSON file within a Foundry test.
 * @dev This contract uses Foundry's cheatcodes (`vm`) to interact with the file system
 * during tests.
 */
contract TestJson is Test {

    // =============================================================================================
    // Test Functions
    // =============================================================================================

    /**
     * @notice Tests the ability to read a JSON file from the file system.
     * @dev This function uses `vm.readFile()` which is a Foundry cheatcode.
     * The primary purpose here is likely to load test data, configurations,
     * or expected values from an external JSON file for more complex test scenarios.
     */
    function test() public view {
        // Attempt to read the content of "test/eigen-layer/root.json".
        // `vm.readFile()` is a Foundry cheatcode that allows tests to access the file system.
        // The return value (string containing the file content) is not used or asserted here,
        // implying this test is a basic check for file accessibility or a setup step
        // for other tests that would parse and use this JSON data.
        vm.readFile("test/eigen-layer/root.json");
    }
}