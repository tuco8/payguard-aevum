// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "./interfaces/IERC20.sol";

/// @title PayGuard
/// @notice A budgeted, revocable agent payment vault for the Aevum Builder Challenge #1.
/// @dev Payers deposit tUSD8 once, grant time-boxed budgets to agent keys, and agents
///      can only pay pre-registered, confirmed payees. Funds stay in escrow until the
///      merchant releases them or the payer refunds before the settlement deadline.
contract PayGuard {
    enum InvoiceStatus {
        None,
        Created,
        Paid,
        Released,
        Refunded,
        Cancelled
    }

    struct Session {
        uint256 budget;
        uint256 spent;
        uint64 expiry;
        bool active;
    }

    struct Invoice {
        address payer;
        address merchant;
        uint256 amount;
        bytes32 payeeHash;
        bytes32 memoHash;
        uint64 createdAt;
        uint64 payBy;
        uint64 releaseBy;
        InvoiceStatus status;
        address paidByAgent;
    }

    IERC20 public immutable token;
    uint256 public invoiceCount;

    mapping(uint256 => Invoice) private _invoices;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => Session)) private _sessions;
    mapping(address => bytes32) public payeeRegistry;

    event Deposited(address indexed payer, uint256 amount, uint256 newBalance);
    event Withdrawn(address indexed payer, uint256 amount, uint256 newBalance);
    event PayeeRegistered(address indexed payee, bytes32 indexed nameHash);
    event SessionAuthorized(address indexed payer, address indexed agent, uint256 budget, uint64 expiry);
    event SessionRevoked(address indexed payer, address indexed agent);
    event InvoiceCreated(
        uint256 indexed invoiceId,
        address indexed payer,
        address indexed merchant,
        uint256 amount,
        uint64 payBy,
        bytes32 payeeHash,
        bytes32 memoHash
    );
    event InvoicePaid(
        uint256 indexed invoiceId,
        address indexed payer,
        address merchant,
        address indexed agent,
        uint256 amount
    );
    event InvoiceReleased(uint256 indexed invoiceId, address indexed merchant, uint256 amount);
    event InvoiceRefunded(uint256 indexed invoiceId, address indexed payer, uint256 amount);
    event InvoiceCancelled(uint256 indexed invoiceId);

    error ZeroAddress();
    error ZeroAmount();
    error Expired();
    error Unauthorized();
    error InvalidStatus();
    error InsufficientBalance();
    error InsufficientBudget();
    error PayeeMismatch();

    constructor(address token_) {
        if (token_ == address(0)) revert ZeroAddress();
        token = IERC20(token_);
    }

    /// @notice Registers the caller's human-readable payee identity hash.
    function registerPayee(bytes32 nameHash) external {
        if (nameHash == bytes32(0)) revert ZeroAmount();
        payeeRegistry[msg.sender] = nameHash;
        emit PayeeRegistered(msg.sender, nameHash);
    }

    /// @notice Deposit tUSD8 into the caller's internal PayGuard balance.
    /// @dev Caller must approve this contract first.
    function deposit(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        balanceOf[msg.sender] += amount;
        require(token.transferFrom(msg.sender, address(this), amount), "deposit: transfer failed");
        emit Deposited(msg.sender, amount, balanceOf[msg.sender]);
    }

    /// @notice Withdraw unused tUSD8 from the caller's internal balance.
    function withdraw(uint256 amount) external {
        if (amount == 0) revert ZeroAmount();
        if (balanceOf[msg.sender] < amount) revert InsufficientBalance();
        balanceOf[msg.sender] -= amount;
        require(token.transfer(msg.sender, amount), "withdraw: transfer failed");
        emit Withdrawn(msg.sender, amount, balanceOf[msg.sender]);
    }

    /// @notice Grant an agent key a capped, expiring spending budget.
    function authorizeAgent(address agent, uint256 budget, uint64 expiry) external {
        if (agent == address(0)) revert ZeroAddress();
        if (budget == 0) revert ZeroAmount();
        if (expiry <= block.timestamp) revert Expired();
        _sessions[msg.sender][agent] = Session({budget: budget, spent: 0, expiry: expiry, active: true});
        emit SessionAuthorized(msg.sender, agent, budget, expiry);
    }

    /// @notice Instantly revoke an agent key. Previously paid invoices are unaffected.
    function revokeAgent(address agent) external {
        _sessions[msg.sender][agent].active = false;
        emit SessionRevoked(msg.sender, agent);
    }

    /// @notice Create an invoice. Either the payer or the merchant may propose it.
    /// @dev If payeeHash is non-zero, the merchant must already have registered that exact hash.
    function createInvoice(
        address payer,
        address merchant,
        uint256 amount,
        uint64 payBy,
        uint64 releaseBy,
        bytes32 payeeHash,
        bytes32 memoHash
    ) external returns (uint256 invoiceId) {
        if (payer == address(0) || merchant == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (payBy <= block.timestamp || releaseBy <= payBy) revert Expired();
        if (payeeHash != bytes32(0) && payeeRegistry[merchant] != payeeHash) revert PayeeMismatch();

        invoiceId = ++invoiceCount;
        _invoices[invoiceId] = Invoice({
            payer: payer,
            merchant: merchant,
            amount: amount,
            payeeHash: payeeHash,
            memoHash: memoHash,
            createdAt: uint64(block.timestamp),
            payBy: payBy,
            releaseBy: releaseBy,
            status: InvoiceStatus.Created,
            paidByAgent: address(0)
        });
        emit InvoiceCreated(invoiceId, payer, merchant, amount, payBy, payeeHash, memoHash);
    }

    /// @notice Execute payment from an authorized agent's remaining budget into escrow.
    function payInvoice(uint256 invoiceId) external {
        Invoice storage invoice = _invoices[invoiceId];
        if (invoice.status != InvoiceStatus.Created) revert InvalidStatus();
        if (block.timestamp > invoice.payBy) revert Expired();

        bytes32 registeredHash = payeeRegistry[invoice.merchant];
        if (invoice.payeeHash != bytes32(0) && registeredHash != invoice.payeeHash) revert PayeeMismatch();

        Session storage agentSession = _sessions[invoice.payer][msg.sender];
        if (!agentSession.active) revert Unauthorized();
        if (block.timestamp > agentSession.expiry) revert Expired();

        uint256 remaining = agentSession.budget - agentSession.spent;
        if (remaining < invoice.amount) revert InsufficientBudget();
        if (balanceOf[invoice.payer] < invoice.amount) revert InsufficientBalance();

        agentSession.spent += invoice.amount;
        balanceOf[invoice.payer] -= invoice.amount;
        invoice.status = InvoiceStatus.Paid;
        invoice.paidByAgent = msg.sender;

        emit InvoicePaid(invoiceId, invoice.payer, invoice.merchant, msg.sender, invoice.amount);
    }

    /// @notice Release escrowed tUSD8 to the merchant.
    /// @dev Before releaseBy only the merchant or payer may release. After the deadline
    ///      anyone may call this to prevent funds being stuck indefinitely.
    function release(uint256 invoiceId) external {
        Invoice storage invoice = _invoices[invoiceId];
        if (invoice.status != InvoiceStatus.Paid) revert InvalidStatus();
        if (msg.sender != invoice.merchant && msg.sender != invoice.payer && block.timestamp < invoice.releaseBy) {
            revert Unauthorized();
        }

        invoice.status = InvoiceStatus.Released;
        require(token.transfer(invoice.merchant, invoice.amount), "release: transfer failed");
        emit InvoiceReleased(invoiceId, invoice.merchant, invoice.amount);
    }

    /// @notice Return an unpaid-but-escrowed invoice to the payer's internal balance.
    function refund(uint256 invoiceId) external {
        Invoice storage invoice = _invoices[invoiceId];
        if (invoice.status != InvoiceStatus.Paid) revert InvalidStatus();
        if (msg.sender != invoice.payer) revert Unauthorized();
        if (block.timestamp >= invoice.releaseBy) revert Expired();

        invoice.status = InvoiceStatus.Refunded;
        balanceOf[invoice.payer] += invoice.amount;
        emit InvoiceRefunded(invoiceId, invoice.payer, invoice.amount);
    }

    /// @notice Cancel an invoice that has not been paid yet.
    function cancel(uint256 invoiceId) external {
        Invoice storage invoice = _invoices[invoiceId];
        if (invoice.status != InvoiceStatus.Created) revert InvalidStatus();
        if (msg.sender != invoice.payer && msg.sender != invoice.merchant) revert Unauthorized();
        invoice.status = InvoiceStatus.Cancelled;
        emit InvoiceCancelled(invoiceId);
    }

    function getInvoice(uint256 invoiceId) external view returns (Invoice memory) {
        return _invoices[invoiceId];
    }

    function session(address payer, address agent) external view returns (Session memory) {
        return _sessions[payer][agent];
    }

    function sessionRemaining(address payer, address agent) external view returns (uint256) {
        Session storage current = _sessions[payer][agent];
        if (!current.active || block.timestamp > current.expiry) return 0;
        return current.budget - current.spent;
    }
}
