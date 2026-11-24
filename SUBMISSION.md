# DoraHacks submission draft — PayGuard

Paste/adapt this into the Aevum Builder Challenge #1 submission form on <https://dorahacks.io/hackathon/qday>. Do **not** paste private keys, `.env`, or any local-only file.

## Project name

**PayGuard — Budgeted Agent Payments on Aevum**

## One-line description

A tUSD8 payment vault that lets a human pre-fund a balance, grant a capped and expiring budget to an AI agent key, restrict payments to registered payees, and hold funds in escrow until the merchant releases them.

## Track

Invoice Payments · Confirmation of Payee · Native AI Assistants

## Problem

AI agents and automated payment bots need to spend stablecoins, but giving them a normal wallet hands over unrestricted control of the whole balance. Merchants also need a way to prove they are the intended payee before funds are committed.

## Solution

PayGuard separates **custody** from **execution**:

- The human payer deposits tUSD8 into the vault and can withdraw unused funds at any time.
- The payer grants an agent key a session with a spending cap and expiry; revocation is immediate.
- The merchant registers a payee identity hash on-chain; an invoice can only be paid to that confirmed hash.
- Invoices are idempotent (one payment per invoice) and carry a pay-by deadline.
- Payment moves funds into escrow; the merchant or payer releases before the settlement deadline, after which anyone can release so funds cannot be stuck. The payer can refund before the deadline.

## Architecture

`Payer → approve + deposit tUSD8 → PayGuard vault → authorizeAgent(cap, expiry) → Agent → payInvoice(invoiceId) → Escrow → Merchant release → tUSD8 to merchant`

Core state: `balanceOf[payer]`, `_sessions[payer][agent]`, `payeeRegistry[merchant]`, `_invoices[id]`.

## Workflows

1. Merchant registers `keccak256("Acme Studio")` as its payee identity.
2. Payer approves and deposits 5 tUSD8.
3. Payer authorizes the agent with a 5 tUSD8 cap and one-hour expiry.
4. Merchant creates invoice #1 for 2 tUSD8, binding payer, merchant, payee hash, memo hash, pay-by, and release-by.
5. Agent calls `payInvoice(1)`; the contract checks payee registration, session active, expiry, remaining budget, and payer balance.
6. Merchant calls `release(1)`; 2 tUSD8 moves from escrow to the merchant.

## Technology

- Solidity `0.8.20`, Foundry `1.10.0`
- Aevum Testnet chain `44005`, RPC `https://rpc-test.qday.info`, explorer <https://explorer-test.qday.info>
- tUSD8 `0x456569838f1d43009A91ebA4263147Afd7233483` (6 decimals)
- EVM version pinned to Shanghai; legacy type-0 transactions used, matching QDay tooling
- Static ethers.js frontend for the same flow; 13 Foundry unit tests cover happy path, double payment, unauthorized agent, budget cap, expiry, payee mismatch, zero amount, refund, revocation, and withdrawal

## Links to include in the form

- Public GitHub repo: `PENDING — publish first`
- Live contract: <https://explorer-test.qday.info/address/0x55A357F9097Ab0C6F711EF23c46c6d32F0f1cFe2>
- Deploy transaction: <https://explorer-test.qday.info/tx/0x923e5fcbc6fcc858152aebf2cb6eaefa91bd0dd5acf232e2f9db3cc7639eb0d6>
- Demo video: `PENDING — record first`
- Evidence/transactions: see `EVIDENCE.md` in the repository

## Key transaction hashes

| Action | Hash |
| --- | --- |
| Deploy | `0x923e5fcbc6fcc858152aebf2cb6eaefa91bd0dd5acf232e2f9db3cc7639eb0d6` |
| Approve | `0xd314ad2b1d5d839932892beddbb061702043930d48f96dc3f46f5ba74b2561b3` |
| Deposit | `0xc2c5235f714bcc62e262646f54585cb725e89848b352b3789b8b30e5d836c792` |
| Register payee | `0x1c2be2434489dc75956d08338c8ea43c0fbb9128b00e91e06a2e2e9c5bfc442c` |
| Authorize agent | `0xdfc8c2d7eab7f4b7a20f601d2050e0d0d832c7c3569af89760c96c50048abf7f` |
| Create invoice | `0xb39200cf890084ebf053707f8d7eb5017e97732f7134e614368e2fb13ce9979b` |
| Agent pays | `0x1190a27a98318addb9f2012955f0558ae98540901cc991920cb058836fe981ab` |
| Merchant releases | `0x979fb3c4e580e7040ccce2b14deb6c7f643639f3bbaec937151e327568a8c331` |

## Verified final state

Invoice #1 status is `Released`; the merchant received 2 tUSD8; the payer retains 3 tUSD8 in the vault; the agent has 3 tUSD8 of remaining budget. RPC-verified details are in `EVIDENCE.md`.

## Judging criteria mapping

| Criterion | Where PayGuard addresses it |
| --- | --- |
| UX and presentation | Static web interface with plain-language status; README narrative and Mermaid architecture diagram |
| Demo clear and well-structured | `DEMO_SCRIPT.md`, `EVIDENCE.md`, 8 explorer-linked transactions, RPC-verified final state; edge cases covered by tests |
| Comprehensive documentation | README with problem, architecture, workflows, tech stack, environment variables, deployment commands, known Aevum constraints, and reproduction steps |
| Innovation and originality | Combines scoped agent session keys, on-chain payee confirmation, idempotent invoices, and escrow/refund in one small primitive |
| Technical quality and platform integration | 13 passing Foundry tests, Shanghai-targeted bytecode, legacy transactions, direct tUSD8 integration on Aevum chain 44005 |
| Real-world utility | Fits merchant invoice payment and automated agent purchasing; payer retains custody and withdrawal rights |
| Safety, trust and controls | Least-privilege agent sessions, expiry, spend cap, instant revocation, payee hash check, deterministic release/refund, full on-chain audit trail |

## Rules/credit

Uses free Aevum testnet tokens only. No mainnet funds, paid services, or production systems were used. Based on the official Aevum Starter Kit (MIT, PQA Labs) for network/token parameters and EIP-3009 gasless-pattern guidance; the PayGuard contract and tests are original work in this repo.

## Reminder

No prize has been claimed or received. This is a submission draft only.
