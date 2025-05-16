// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "forge-std/Test.sol";

contract TestJson is Test {
    function test() public view {
        vm.readFile("test/eigen-layer/root.json");
    }
}
