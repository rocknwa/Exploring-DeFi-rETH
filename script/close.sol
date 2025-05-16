// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "forge-std/Script.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {
    RETH,
    DAI,
    UNISWAP_V3_POOL_FEE_DAI_WETH,
    BALANCER_POOL_ID_RETH_WETH
} from "@src/helpers/Constants.sol";
import {PROXY, FLASH_LEV, RETH_AMOUNT} from "./config.sol";
import {Proxy} from "@src/helpers/Proxy.sol";
import {FlashLev} from "@src/FlashLev.sol";
import {AaveLib} from "./lib.sol";

contract CloseScript is Script, AaveLib {
    IERC20 constant reth = IERC20(RETH);
    IERC20 constant dai = IERC20(DAI);
    Proxy constant proxy = Proxy(payable(PROXY));
    FlashLev constant flashLev = FlashLev(FLASH_LEV);

    function run() public {
        uint256 coinBalBefore = dai.balanceOf(msg.sender);
        uint256 colBalBefore = reth.balanceOf(msg.sender);
        uint256 coinDebt = flashLev.getDebt(address(proxy), DAI);

        console.log("Debt: %e", coinDebt);

        vm.startBroadcast();

        proxy.execute(
            address(flashLev),
            abi.encodeCall(
                flashLev.close,
                (
                    FlashLev.CloseParams({
                        coin: DAI,
                        collateral: RETH,
                        colAmount: RETH_AMOUNT,
                        swap: FlashLev.SwapParams({
                            amountOutMin: coinDebt * 98 / 100,
                            data: abi.encode(
                                false,
                                UNISWAP_V3_POOL_FEE_DAI_WETH,
                                BALANCER_POOL_ID_RETH_WETH
                            )
                        })
                    })
                )
            )
        );

        vm.stopBroadcast();

        uint256 coinBalAfter = dai.balanceOf(msg.sender);

        if (coinBalAfter >= coinBalBefore) {
            console.log("Profit: %e", coinBalAfter - coinBalBefore);
        } else {
            console.log("Loss: %e", coinBalBefore - coinBalAfter);
        }

        uint256 colBalAfter = reth.balanceOf(msg.sender);
        console.log("Collateral delta: %e", colBalAfter - colBalBefore);

        // Log info
        getInfo(address(proxy));
    }
}
