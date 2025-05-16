// SPDX-License-Identifier: MIT
pragma solidity ^0.8;

import "forge-std/Test.sol";
import {Proxy} from "@src/helpers/Proxy.sol";
import {ProxyFactory} from "@src/helpers/ProxyFactory.sol";

interface ITransferHook {
    function onTransfer(address src, address dst, uint256 amount) external;
}

contract Token {
    mapping(address => uint256) public balances;

    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }

    function transfer(address to, uint256 amount) external {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        ITransferHook(msg.sender).onTransfer(msg.sender, to, amount);
    }
}

contract Target is ITransferHook {
    function pay(address to, uint256 amount) external {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "pay failed");
    }

    function transfer(address token, address to, uint256 amount) external {
        Token(token).transfer(to, amount);
    }

    function onTransfer(address src, address dst, uint256 amount)
        external
        pure
    {
        require(src != dst, "src = dst");
        require(dst != address(0), "dst = 0 addr");
        require(amount > 0, "amount = 0");
    }
}

contract ProxyTest is Test {
    Proxy proxy;
    Token token;
    Target target;

    function setUp() public {
        proxy = new Proxy(address(this));
        token = new Token();
        target = new Target();

        token.mint(address(proxy), 100);

        (bool ok,) = address(proxy).call{value: 100}("");
        require(ok, "send failed");
    }

    function test_owner() public view {
        assertEq(proxy.owner(), address(this));
    }

    function test_execute_auth() public {
        vm.expectRevert("not authorized");
        vm.prank(address(1));
        proxy.execute(
            address(target), abi.encodeCall(Target.pay, (address(2), 100))
        );
    }

    function test_execute_fail() public {
         vm.expectRevert("delegatecall failed");
 proxy.execute{ value: 10_000 }(
    address(target),
    abi.encodeCall(Target.pay, (address(2), 10_000))
  );
    }

    function test_execute() public {
        address dst = address(2);
        proxy.execute(address(target), abi.encodeCall(Target.pay, (dst, 100)));
       // assertEq(dst.balance, 100);
    }

    function test_fallback() public {
        address dst = address(2);
        proxy.execute(
            address(target),
            abi.encodeCall(Target.transfer, (address(token), dst, 100))
        );
        assertEq(token.balances(dst), 100);
    }

    function test_fallback_fail() public {
      vm.expectRevert("delegatecall failed");
        proxy.execute(
            address(target),
            abi.encodeCall(Target.transfer, (address(token), address(0), 100))
        );
    }
}

contract ProxyFactoryTest is Test {
    ProxyFactory factory;

    function setUp() public {
        factory = new ProxyFactory();
    }

    function test_deploy() public {
        address addr = factory.deploy();
        assertEq(Proxy(payable(addr)).owner(), address(this));
    }
}