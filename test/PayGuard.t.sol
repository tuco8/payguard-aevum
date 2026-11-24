// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {PayGuard} from "../src/PayGuard.sol";

/// @dev Minimal Foundry cheatcode surface; avoids an external forge-std dependency.
interface Vm {
    function prank(address sender) external;
    function warp(uint256 timestamp) external;
    function expectRevert(bytes calldata reason) external;
}

contract MockERC20 {
    string public name = "Test USD8";
    string public symbol = "tUSD8";
    uint8 public decimals = 6;

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    function mint(address to, uint256 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        if (allowed != type(uint256).max) {
            require(allowed >= amount, "allowance");
            allowance[from][msg.sender] = allowed - amount;
        }
        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(balanceOf[from] >= amount, "balance");
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        emit Transfer(from, to, amount);
    }
}

contract PayGuardTest {
    Vm internal constant vm = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    address internal constant PAYER = address(0xA11CE);
    address internal constant MERCHANT = address(0xB0B);
    address internal constant AGENT = address(0xC0DE);
    address internal constant OUTSIDER = address(0xD00D);

    bytes32 internal constant PAYEE_HASH = keccak256("Acme Studio");
    bytes32 internal constant MEMO_HASH = keccak256("invoice-2026-001");

    MockERC20 internal token;
    PayGuard internal guard;

    function setUp() public {
        token = new MockERC20();
        guard = new PayGuard(address(token));
    }

    function _fundAndDeposit(uint256 amount) internal {
        token.mint(PAYER, amount);
        vm.prank(PAYER);
        token.approve(address(guard), amount);
        vm.prank(PAYER);
        guard.deposit(amount);
    }

    function _registerMerchant() internal {
        vm.prank(MERCHANT);
        guard.registerPayee(PAYEE_HASH);
    }

    function _authorizeAgent(uint256 budget, uint64 lifetime) internal {
        vm.prank(PAYER);
        guard.authorizeAgent(AGENT, budget, uint64(block.timestamp + lifetime));
    }

    function _createInvoice(uint256 amount, uint256 payWindow, uint256 releaseWindow)
        internal
        returns (uint256 id)
    {
        vm.prank(MERCHANT);
        id = guard.createInvoice(
            PAYER,
            MERCHANT,
            amount,
            uint64(block.timestamp + payWindow),
            uint64(block.timestamp + releaseWindow),
            PAYEE_HASH,
            MEMO_HASH
        );
    }

    function assertEq(uint256 a, uint256 b) internal pure {
        require(a == b, "assertEq(uint256) failed");
    }

    function assertTrue(bool value) internal pure {
        require(value, "assertTrue failed");
    }

    function test_happyPath_payThenRelease() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 3600);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.prank(AGENT);
        guard.payInvoice(id);

        PayGuard.Invoice memory invoice = guard.getInvoice(id);
        assertEq(uint256(invoice.status), uint256(PayGuard.InvoiceStatus.Paid));
        assertEq(guard.balanceOf(PAYER), 75e6);
        assertEq(guard.sessionRemaining(PAYER, AGENT), 25e6);
        assertEq(token.balanceOf(MERCHANT), 0);

        vm.prank(MERCHANT);
        guard.release(id);

        invoice = guard.getInvoice(id);
        assertEq(uint256(invoice.status), uint256(PayGuard.InvoiceStatus.Released));
        assertEq(token.balanceOf(MERCHANT), 25e6);
        assertEq(token.balanceOf(address(guard)), 75e6);
    }

    function test_doublePaymentReverts() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 3600);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.prank(AGENT);
        guard.payInvoice(id);

        vm.prank(AGENT);
        vm.expectRevert(abi.encodeWithSignature("InvalidStatus()"));
        guard.payInvoice(id);
    }

    function test_unauthorizedAgentCannotPay() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 3600);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.prank(OUTSIDER);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        guard.payInvoice(id);
    }

    function test_sessionBudgetCapEnforced() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(10e6, 3600);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.prank(AGENT);
        vm.expectRevert(abi.encodeWithSignature("InsufficientBudget()"));
        guard.payInvoice(id);
    }

    function test_expiredSessionCannotPay() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 60);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.warp(block.timestamp + 61);

        vm.prank(AGENT);
        vm.expectRevert(abi.encodeWithSignature("Expired()"));
        guard.payInvoice(id);
    }

    function test_expiredPayByCannotPay() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 3600);
        uint256 id = _createInvoice(25e6, 60, 7200);

        vm.warp(block.timestamp + 61);

        vm.prank(AGENT);
        vm.expectRevert(abi.encodeWithSignature("Expired()"));
        guard.payInvoice(id);
    }

    function test_payeeMismatchReverts() public {
        _fundAndDeposit(100e6);
        vm.prank(MERCHANT);
        guard.registerPayee(keccak256("Different Payee"));

        vm.prank(MERCHANT);
        vm.expectRevert(abi.encodeWithSignature("PayeeMismatch()"));
        guard.createInvoice(
            PAYER,
            MERCHANT,
            25e6,
            uint64(block.timestamp + 1800),
            uint64(block.timestamp + 7200),
            PAYEE_HASH,
            MEMO_HASH
        );
    }

    function test_zeroAmountInvoiceReverts() public {
        vm.prank(MERCHANT);
        vm.expectRevert(abi.encodeWithSignature("ZeroAmount()"));
        guard.createInvoice(
            PAYER,
            MERCHANT,
            0,
            uint64(block.timestamp + 1800),
            uint64(block.timestamp + 7200),
            PAYEE_HASH,
            MEMO_HASH
        );
    }

    function test_refundReturnsFundsBeforeDeadline() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 3600);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.prank(AGENT);
        guard.payInvoice(id);

        vm.prank(PAYER);
        guard.refund(id);

        PayGuard.Invoice memory invoice = guard.getInvoice(id);
        assertEq(uint256(invoice.status), uint256(PayGuard.InvoiceStatus.Refunded));
        assertEq(guard.balanceOf(PAYER), 100e6);
        assertEq(token.balanceOf(MERCHANT), 0);
    }

    function test_refundAfterDeadlineReverts() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 3600);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.prank(AGENT);
        guard.payInvoice(id);

        vm.warp(block.timestamp + 7201);

        vm.prank(PAYER);
        vm.expectRevert(abi.encodeWithSignature("Expired()"));
        guard.refund(id);
    }

    function test_anyoneCanReleaseAfterDeadline() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 3600);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.prank(AGENT);
        guard.payInvoice(id);

        vm.warp(block.timestamp + 7201);

        vm.prank(OUTSIDER);
        guard.release(id);

        assertEq(token.balanceOf(MERCHANT), 25e6);
    }

    function test_revokeStopsAgentImmediately() public {
        _fundAndDeposit(100e6);
        _registerMerchant();
        _authorizeAgent(50e6, 3600);
        uint256 id = _createInvoice(25e6, 1800, 7200);

        vm.prank(PAYER);
        guard.revokeAgent(AGENT);

        vm.prank(AGENT);
        vm.expectRevert(abi.encodeWithSignature("Unauthorized()"));
        guard.payInvoice(id);
    }

    function test_withdrawUnusedBalance() public {
        _fundAndDeposit(100e6);

        vm.prank(PAYER);
        guard.withdraw(40e6);

        assertEq(guard.balanceOf(PAYER), 60e6);
        assertEq(token.balanceOf(PAYER), 40e6);
    }
}
