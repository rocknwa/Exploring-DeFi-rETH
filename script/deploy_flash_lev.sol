// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {FlashLev} from "@src/FlashLev.sol";

contract DeployFlashLevScript is Script {
    function run() public {
        vm.startBroadcast();
        new FlashLev();
        vm.stopBroadcast();
    }
}
