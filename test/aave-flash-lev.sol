// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {IPool} from "@src/interfaces/aave/IPool.sol";
import {IAaveOracle} from "@src/interfaces/aave/IAaveOracle.sol";
import {IPoolDataProvider} from "@src/interfaces/aave/IPoolDataProvider.sol";
import {IVault} from "@src/interfaces/balancer/IVault.sol";
import {ISwapRouter} from "@src/interfaces/uniswap/ISwapRouter.sol";
import {
    WETH,
    RETH,
    DAI,
    AAVE_POOL,
    AAVE_ORACLE,
    AAVE_POOL_DATA_PROVIDER,
    BALANCER_VAULT,
    BALANCER_POOL_RETH_WETH,
    BALANCER_POOL_ID_RETH_WETH,
    UNISWAP_V3_SWAP_ROUTER_02,
    UNISWAP_V3_POOL_FEE_DAI_WETH
} from "@src/helpers/Constants.sol";
import {Proxy} from "@src/helpers/Proxy.sol";
import {FlashLev} from "@src/FlashLev.sol";

// forge test --fork-url $FORK_URL --evm-version cancun --match-path test/exercise-aave.sol -vvv

contract FlashLevTest is Test {
    IRETH constant reth = IRETH(RETH);
    IERC20 constant weth = IERC20(WETH);
    IERC20 constant dai = IERC20(DAI);
    IPool constant pool = IPool(AAVE_POOL);
    Proxy proxy;
    FlashLev flashLev;

    function setUp() public {
        flashLev = new FlashLev();
        proxy = new Proxy(address(this));

        deal(RETH, address(this), 1e18);
        deal(DAI, address(this), 1000 * 1e18);

        reth.approve(address(proxy), type(uint256).max);
        dai.approve(address(proxy), type(uint256).max);

        vm.label(address(proxy), "Proxy");
        vm.label(address(flashLev), "FlashLev");
        vm.label(address(AAVE_POOL), "Pool");
    }

    struct Info {
        uint256 hf;
        uint256 col;
        uint256 debt;
        uint256 available;
    }

    function getInfo(address user) public view returns (Info memory) {
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            uint256 availableBorrowsBase,
            uint256 currentLiquidationThreshold,
            uint256 ltv,
            uint256 healthFactor
        ) = pool.getUserAccountData(user);

        console.log("Collateral USD: %e", totalCollateralBase);
        console.log("Debt USD: %e", totalDebtBase);
        console.log("Available to borrow USD: %e", availableBorrowsBase);
        console.log("LTV: %e", ltv);
        console.log("Liquidation threshold: %e", currentLiquidationThreshold);
        console.log("Health factor: %e", healthFactor);

        return Info({
            hf: healthFactor,
            col: totalCollateralBase,
            debt: totalDebtBase,
            available: availableBorrowsBase
        });
    }

    function test_getMaxFlashLoanAmountUsd() public view {
        uint256 colAmount = 1e18;

        (uint256 max, uint256 price, uint256 ltv, uint256 maxLev) =
            flashLev.getMaxFlashLoanAmountUsd(RETH, colAmount);
        console.log("Max flash loan USD: %e", max);
        console.log("Collateral price: %e", price);
        console.log("LTV: %e", ltv);
        console.log("Max leverage %e", maxLev);

        assertGt(price, 0);
        assertGe(max, colAmount * price / 1e8);
        assertGt(ltv, 0);
        assertLe(ltv, 1e4);
        assertGt(maxLev, 0);
    }

    function test_flashLev() public {
        uint256 colAmount = 1e18;

        (uint256 max, uint256 price, uint256 ltv, uint256 maxLev) =
            flashLev.getMaxFlashLoanAmountUsd(RETH, colAmount);
        console.log("Max flash loan USD: %e", max);
        console.log("Collateral price: %e", price);
        console.log("LTV: %e", ltv);
        console.log("Max leverage %e", maxLev);

        console.log("--------- open ------------");

        // Assumes 1 coin = 1 USD
        uint256 coinAmount = max * 98 / 100;

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
                            amountOutMin: coinAmount * 1e8 / price * 98 / 100,
                            data: abi.encode(
                                true,
                                UNISWAP_V3_POOL_FEE_DAI_WETH,
                                BALANCER_POOL_ID_RETH_WETH
                            )
                        }),
                        minHealthFactor: 1.01 * 1e18
                    })
                )
            )
        );

        Info memory info;
        info = getInfo(address(proxy));

        assertGt(info.col, 0);
        assertGt(info.debt, 0);
        assertGt(info.hf, 1e18);
        assertLt(info.hf, 1.1 * 1e18);

        console.log("--------- close ------------");
        uint256 coinBalBefore = dai.balanceOf(address(this));
        uint256 coinDebt = flashLev.getDebt(address(proxy), DAI);

        proxy.execute(
            address(flashLev),
            abi.encodeCall(
                flashLev.close,
                (
                    FlashLev.CloseParams({
                        coin: DAI,
                        collateral: RETH,
                        colAmount: colAmount,
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

        uint256 coinBalAfter = dai.balanceOf(address(this));

        info = getInfo(address(proxy));

        assertEq(info.col, 0);
        assertEq(info.debt, 0);
        assertGt(info.hf, 1e18);

        if (coinBalAfter >= coinBalBefore) {
            console.log("Profit: %e", coinBalAfter - coinBalBefore);
        } else {
            console.log("Loss: %e", coinBalBefore - coinBalAfter);
        }

        uint256 colBal = reth.balanceOf(address(this));
        console.log("Collateral: %e", colBal);

        assertEq(colBal, colAmount);
    }
}
