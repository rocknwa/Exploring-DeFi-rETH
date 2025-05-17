// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @title ProxyTestSuite
/// @notice Test suite for Proxy and ProxyFactory contracts
/// @dev Uses Forge testing framework to test proxy functionality and token transfers
import "forge-std/Test.sol";
import {Proxy} from "@src/helpers/Proxy.sol";
import {ProxyFactory} from "@src/helpers/ProxyFactory.sol";

/// @notice Interface for transfer hook callback
interface ITransferHook {
    /// @notice Called on token transfer
    /// @param src Source address
    /// @param dst Destination address
    /// @param amount Amount transferred
    function onTransfer(address src, address dst, uint256 amount) external;
}

/// @title Token
/// @notice Simple ERC20-like token with minting and transfer functionality
/// @dev Includes a transfer hook for external validation
contract Token {
    /// @notice Mapping of address to token balances
    mapping(address => uint256) public balances;

    /// @notice Mints tokens to a specified address
    /// @param to Recipient address
    /// @param amount Amount to mint
    function mint(address to, uint256 amount) external {
        balances[to] += amount;
    }

    /// @notice Transfers tokens to a specified address
    /// @param to Recipient address
    /// @param amount Amount to transfer
    /// @dev Calls onTransfer hook on the sender
    function transfer(address to, uint256 amount) external {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        ITransferHook(msg.sender).onTransfer(msg.sender, to, amount);
    }
}

/// @title Target
/// @notice Contract for handling payments and token transfers
/// @dev Implements ITransferHook for transfer validation
contract Target is ITransferHook {
    /// @notice Sends ETH to a specified address
    /// @param to Recipient address
    /// @param amount Amount of ETH to send
    function pay(address to, uint256 amount) external {
        (bool ok,) = to.call{value: amount}("");
        require(ok, "pay failed");
    }

    /// @notice Initiates a token transfer
    /// @param token Token contract address
    /// @param to Recipient address
    /// @param amount Amount to transfer
    function transfer(address token, address to, uint256 amount) external {
        Token(token).transfer(to, amount);
    }

    /// @notice Validates token transfer
    /// @param src Source address
    /// @param dst Destination address
    /// @param amount Amount transferred
    /// @dev Reverts if transfer is invalid
    function onTransfer(address src, address dst, uint256 amount)
        external
        pure
        override
    {
        require(src != dst, "src = dst");
        require(dst != address(0), "dst = 0 addr");
        require(amount > 0, "amount = 0");
    }
}

/// @title ProxyTest
/// @notice Tests for Proxy contract functionality
/// @dev Tests ownership, execution, and fallback behavior
contract ProxyTest is Test {
    /// @notice Proxy contract instance
    Proxy internal proxy;
    /// @notice Token contract instance
    Token internal token;
    /// @notice Target contract instance
    Target internal target;

    /// @notice Sets up the test environment
    /// @dev Deploys contracts, mints tokens, and funds proxy with ETH
    function setUp() public {
        // Deploy Proxy with this contract as owner
        proxy = new Proxy(address(this));
        // Deploy Token and Target contracts
        token = new Token();
        target = new Target();

        // Mint 100 tokens to proxy
        token.mint(address(proxy), 100);

        // Send 100 wei to proxy
        (bool ok,) = address(proxy).call{value: 100}("");
        require(ok, "send failed");
    }

    /// @notice Tests proxy ownership
    /// @dev Verifies that the test contract is the proxy owner
    function test_owner() public view {
        assertEq(proxy.owner(), address(this), "Owner should be test contract");
    }

    /// @notice Tests unauthorized execute call
    /// @dev Verifies that non-owner execution reverts
    function test_execute_auth() public {
        vm.expectRevert("not authorized");
        vm.prank(address(1));
        proxy.execute(
            address(target), abi.encodeCall(Target.pay, (address(2), 100))
        );
    }

    /// @notice Tests execute call with insufficient funds
    /// @dev Verifies that delegatecall fails due to low balance
    function test_execute_fail() public {
        vm.expectRevert("delegatecall failed");
        proxy.execute{value: 10_000}(
            address(target),
            abi.encodeCall(Target.pay, (address(2), 10_000))
        );
    }

    /// @notice Tests successful execute call
    /// @dev Verifies ETH transfer via delegatecall
    function test_execute() public {
        address dst = address(2);
        proxy.execute(address(target), abi.encodeCall(Target.pay, (dst, 100)));
        // Note: Balance assertion commented out in original code
        // assertEq(dst.balance, 100, "Destination should receive 100 wei");
    }

    /// @notice Tests fallback behavior with token transfer
    /// @dev Verifies token transfer through proxy and hook validation
    function test_fallback() public {
        address dst = address(2);
        proxy.execute(
            address(target),
            abi.encodeCall(Target.transfer, (address(token), dst, 100))
        );
        assertEq(token.balances(dst), 100, "Destination should have 100 tokens");
    }

    /// @notice Tests fallback with invalid token transfer
    /// @dev Verifies that transfer to zero address fails
    function test_fallback_fail() public {
        vm.expectRevert("delegatecall failed");
        proxy.execute(
            address(target),
            abi.encodeCall(Target.transfer, (address(token), address(0), 100))
        );
    }
}

/// @title ProxyFactoryTest
/// @notice Tests for ProxyFactory contract
/// @dev Tests proxy deployment and ownership
contract ProxyFactoryTest is Test {
    /// @notice ProxyFactory contract instance
    ProxyFactory internal factory;

    /// @notice Sets up the test environment
    /// @dev Deploys ProxyFactory contract
    function setUp() public {
        factory = new ProxyFactory();
    }

    /// @notice Tests proxy deployment
    /// @dev Verifies that deployed proxy has correct owner
    function test_deploy() public {
        address addr = factory.deploy();
        assertEq(
            Proxy(payable(addr)).owner(),
            address(this),
            "Owner should be test contract"
        );
    }
}