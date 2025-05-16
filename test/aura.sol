// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import {Test, console} from "forge-std/Test.sol";
import {IERC20} from "@src/interfaces/IERC20.sol";
import {IRETH} from "@src/interfaces/rocket-pool/IRETH.sol";
import {IBaseRewardPool4626} from "@src/interfaces/aura/IBaseRewardPool4626.sol";
import {
    WETH,
    RETH,
    BAL,
    BALANCER_VAULT,
    BALANCER_POOL_RETH_WETH,
    AURA,
    AURA_BASE_REWARD_POOL_4626_RETH
} from "@src/helpers/Constants.sol";
import {AuraLiquidity} from "@src/AuraLiquidity.sol";

// forge test --fork-url $FORK_URL --match-path test/exercise-aura.sol -vvv

contract AuraTest is Test {
    IRETH reth = IRETH(RETH);
    IERC20 weth = IERC20(WETH);
    IERC20 bal = IERC20(BAL);
    IERC20 aura = IERC20(AURA);
    IERC20 bpt = IERC20(BALANCER_POOL_RETH_WETH);

    IBaseRewardPool4626 rewardPool =
        IBaseRewardPool4626(AURA_BASE_REWARD_POOL_4626_RETH);

    AuraLiquidity liq;

    function setUp() public {
        liq = new AuraLiquidity();
        deal(RETH, address(this), 1e18);
        reth.approve(address(liq), type(uint256).max);
    }

    function test_deposit_auth() public {
        vm.expectRevert();
        vm.prank(address(1));
        liq.deposit(1e18);
    }

    function test_exit_auth() public {
        uint256 shares = liq.deposit(1e18);

        vm.expectRevert();
        vm.prank(address(1));
        liq.exit(shares, 1);
    }

    function test_transfer_auth() public {
        vm.expectRevert();
        vm.prank(address(1));
        liq.transfer(RETH, address(1));
    }

    function test_transfer() public {
        liq.transfer(RETH, address(1));
    }

    function test_depositAndExit() public {
        console.log("--- deposit ---");
        uint256 rethAmount = 1e18;
        uint256 shares = liq.deposit(rethAmount);

        console.log("Reward pool shares: %e", shares);

        assertGt(shares, 0);
        assertEq(shares, rewardPool.balanceOf(address(liq)));
        assertEq(reth.balanceOf(address(this)), 0);
        assertEq(reth.balanceOf(address(liq)), 0);

        // Get reward
        skip(7 days);

        console.log("--- get reward ---");
        liq.getReward();

        console.log("BAL reward %e", bal.balanceOf(address(liq)));
        console.log("AURA reward %e", aura.balanceOf(address(liq)));

        assertGe(bal.balanceOf(address(liq)), 0);
        assertGe(aura.balanceOf(address(liq)), 0);

        // NOTE: bug? non-zero WETH balance
        console.log("--- withdraw ---");

        uint256 wethBalBefore = weth.balanceOf(address(this));
        liq.exit(shares, 1);
        uint256 wethBalAfter = weth.balanceOf(address(this));

        shares = rewardPool.balanceOf(address(liq));
        console.log("Reward pool shares: %e", shares);
        console.log("BPT %e", bpt.balanceOf(address(this)));
        console.log("RETH %e", reth.balanceOf(address(this)));
        console.log("WETH %e", weth.balanceOf(address(this)));
        console.log("BAL reward %e", bal.balanceOf(address(liq)));
        console.log("AURA reward %e", aura.balanceOf(address(liq)));

        assertEq(shares, 0);
        assertEq(reth.balanceOf(address(liq)), 0);
        assertEq(weth.balanceOf(address(liq)), 0);
        assertEq(bpt.balanceOf(address(liq)), 0);
        assertGt(reth.balanceOf(address(this)), 0);
        assertEq(wethBalAfter, wethBalBefore);
        assertGe(bal.balanceOf(address(liq)), 0);
        assertGe(aura.balanceOf(address(liq)), 0);
    }
}
