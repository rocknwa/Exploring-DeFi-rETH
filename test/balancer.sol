// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {IVault} from "@src/interfaces/balancer/IVault.sol";
import {
    WETH,
    RETH,
    BALANCER_VAULT,
    BALANCER_POOL_RETH_WETH,
    BALANCER_POOL_ID_RETH_WETH
} from "@src/helpers/Constants.sol";
import {BalancerLiquidity} from "@src/BalancerLiquidity.sol";

// forge test --fork-url $FORK_URL --match-path test/exercise-balancer.sol -vvv

contract BalancerTest is Test {
    IRETH reth = IRETH(RETH);
    IERC20 weth = IERC20(WETH);
    IVault vault = IVault(BALANCER_VAULT);
    // Balancer Pool Token
    IERC20 bpt = IERC20(BALANCER_POOL_RETH_WETH);

    BalancerLiquidity liq;

    function setUp() public {
        deal(WETH, address(this), 1e18);
        deal(RETH, address(this), 1e18);

        liq = new BalancerLiquidity();

        reth.approve(address(liq), type(uint256).max);
        weth.approve(address(liq), type(uint256).max);
        bpt.approve(address(liq), type(uint256).max);
    }

    function test_join() public {
        uint256 rethAmount = 1e18;
        uint256 wethAmount = 1e18;

        liq.join(rethAmount, wethAmount);

        uint256 bptBal = bpt.balanceOf(address(this));
        console.log("BPT: %e", bptBal);

        assertEq(reth.balanceOf(address(this)), 0);
        assertEq(weth.balanceOf(address(this)), 0);
        assertGt(bpt.balanceOf(address(this)), 0);

        assertEq(reth.balanceOf(address(liq)), 0);
        assertEq(weth.balanceOf(address(liq)), 0);
        assertEq(bpt.balanceOf(address(liq)), 0);
    }

    function test_exit() public {
        uint256 rethAmount = 1e18;
        uint256 wethAmount = 1e18;

        liq.join(rethAmount, wethAmount);

        uint256 minRethAmount = (rethAmount + wethAmount) * 90 / 100;

        uint256 bptBal = bpt.balanceOf(address(this));
        liq.exit(bptBal, minRethAmount);

        console.log("BPT: %e", bpt.balanceOf(address(this)));
        console.log("RETH: %e", reth.balanceOf(address(this)));
        console.log("WETH: %e", weth.balanceOf(address(this)));

        assertGt(reth.balanceOf(address(this)), 0);
        assertEq(weth.balanceOf(address(this)), 0);
        assertEq(bpt.balanceOf(address(this)), 0);

        assertEq(reth.balanceOf(address(liq)), 0);
        assertEq(weth.balanceOf(address(liq)), 0);
        assertEq(bpt.balanceOf(address(liq)), 0);
    }
}
