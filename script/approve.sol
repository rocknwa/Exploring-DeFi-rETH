// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {RETH, DAI} from "@src/helpers/Constants.sol";
import {PROXY, RETH_AMOUNT, DAI_AMOUNT} from "./config.sol";

contract ApproveScript is Script {
    IERC20 constant reth = IERC20(RETH);
    IERC20 constant dai = IERC20(DAI);

    function run() public {
        vm.startBroadcast();
        reth.approve(PROXY, RETH_AMOUNT);
        dai.approve(PROXY, DAI_AMOUNT);
        vm.stopBroadcast();
    }
}
