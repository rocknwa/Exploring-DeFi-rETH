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
import {PROXY, FLASH_LEV, RETH_AMOUNT, MAX_LEV, MIN_HF} from "./config.sol";
import {Proxy} from "@src/helpers/Proxy.sol";
import {FlashLev} from "@src/FlashLev.sol";
import {AaveLib} from "./lib.sol";

contract OpenScript is Script, AaveLib {
    IERC20 constant reth = IERC20(RETH);
    IERC20 constant dai = IERC20(DAI);
    Proxy constant proxy = Proxy(payable(PROXY));
    FlashLev constant flashLev = FlashLev(FLASH_LEV);

    function run() public {
        (uint256 max, uint256 price, uint256 ltv, uint256 maxLev) =
            flashLev.getMaxFlashLoanAmountUsd(RETH, RETH_AMOUNT);
        console.log("Max flash loan (USD): %e", max);
        console.log("Collateral price: %e", price);
        console.log("LTV: %e", ltv);
        console.log("Max leverage: %e", maxLev);

        require(MAX_LEV <= maxLev, "max lev > max");

        uint256 colAmount = RETH_AMOUNT;
        // 1e4 = leverage scale (1e4 = 1)
        // 1e8 = price scalse (1e8 = 1 USD)
        uint256 coinAmount = colAmount * price * MAX_LEV / 1e4 / 1e8;

        console.log("Coin amount: %e", coinAmount);

        require(coinAmount <= max, "coin amount > max");
        require(MIN_HF > 1e18, "min health factor < 1");

        vm.startBroadcast();

        proxy.execute(
            address(flashLev),
            abi.encodeCall(
                flashLev.open,
                (
                    FlashLev.OpenParams({
                        coin: DAI,
                        collateral: RETH,
                        colAmount: colAmount,
                        coinAmount: coinAmount,
                        swap: FlashLev.SwapParams({
                            // 98 / 100 = allow 2% slippage
                            amountOutMin: coinAmount * 1e8 / price * 98 / 100,
                            data: abi.encode(
                                true,
                                UNISWAP_V3_POOL_FEE_DAI_WETH,
                                BALANCER_POOL_ID_RETH_WETH
                            )
                        }),
                        minHealthFactor: MIN_HF
                    })
                )
            )
        );

        vm.stopBroadcast();

        // Log info
        getInfo(address(proxy));
    }
}
