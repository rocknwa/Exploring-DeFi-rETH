// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {PROXY} from "./config.sol";
import {Proxy} from "@src/helpers/Proxy.sol";
import {AaveLib} from "./lib.sol";

contract OpenScript is Script, AaveLib {
    Proxy constant proxy = Proxy(payable(PROXY));

    function run() public view {
        getInfo(address(proxy));
    }
}
