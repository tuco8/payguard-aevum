# Live Testnet Evidence

> Status: **LIVE RUN COMPLETE** on 2026-11-24. All transactions below are real Aevum Testnet transactions, verified by RPC reads after execution. No mainnet funds or production assets were used.

## Deployed contract

| Item | Value |
| --- | --- |
| Network | QDay Aevum Testnet, chain `44005` |
| RPC | `https://rpc-test.qday.info` |
| Explorer | <https://explorer-test.qday.info> |
| PayGuard address | `0x55A357F9097Ab0C6F711EF23c46c6d32F0f1cFe2` |
| Explorer link | <https://explorer-test.qday.info/address/0x55A357F9097Ab0C6F711EF23c46c6d32F0f1cFe2> |
| Constructor arg | tUSD8 `0x456569838f1d43009A91ebA4263147Afd7233483` |
| Deploy tx | `0x923e5fcbc6fcc858152aebf2cb6eaefa91bd0dd5acf232e2f9db3cc7639eb0d6` |
| Deploy explorer | <https://explorer-test.qday.info/tx/0x923e5fcbc6fcc858152aebf2cb6eaefa91bd0dd5acf232e2f9db3cc7639eb0d6> |
| Verification status | Explorer verifier not attempted: QDay starter kit says it is currently broken. Exact source is pinned at commit `26bb13d921c33f403db02abc312a8bfc931e9e5e` in the public repo: <https://github.com/tuco8/payguard-aevum/tree/26bb13d921c33f403db02abc312a8bfc931e9e5e> |

## Roles

| Role | Address |
| --- | --- |
| Payer / deployer | `0xB6dE519D266F355C41fa4Dfe7b72112E30EF35AA` |
| Merchant / payee | `0xc1c4E40c0841a6a4ab22488b161a95D220193F05` |
| Agent key | `0xbF02Ed2Afc6BeE14BB989Eb8351c60030FDc2fd7` |

The user-provided MetaMask address `0xB5C5c5530411b6438Bc10e12fF58B3b1300294F7` was not needed for the final demo: the Discord faucet removes the mainnet-balance gate, and all demo roles use throwaway testnet keys.

## Funding source

| Item | Value |
| --- | --- |
| Route | Official Builder Challenge Discord faucet |
| Source | `qday-io/aevum-starter-kit` README: join Discord, react ✅ in `#verify`, then `/faucet <address>` |
| Amount received | 1 tQDAY + 5 tUSD8 |
| Recipient | `0xB6dE519D266F355C41fa4Dfe7b72112E30EF35AA` |
| Command run by user | `/faucet 0xB6dE519D266F355C41fa4Dfe7b72112E30EF35AA` |
| Status | Confirmed by user; verified on-chain |
| Web-faucet note | `GET /gasapi/eligibility?address=0xB5C5...` returned `{"eligible":false,"via":null}` — the web route requires mainnet holdings, so it was not used. |
| Agent gas top-up | `0xe141db0202be59c6f5730fc3f9ad9ce1402407215175aa56ec4f7a6766c9f12b` — 0.02 tQDAY from payer to agent |
| Merchant gas top-up | `0x3cb7f42d91f0e45f11063d0056498a686ce260c9a9b7076ee16431028703b085` — 0.02 tQDAY from payer to merchant |

## Demo transaction sequence

| Step | Action | Tx hash | Explorer |
| --- | --- | --- | --- |
| 0 | Deploy PayGuard | `0x923e5fcbc6fcc858152aebf2cb6eaefa91bd0dd5acf232e2f9db3cc7639eb0d6` | [view](https://explorer-test.qday.info/tx/0x923e5fcbc6fcc858152aebf2cb6eaefa91bd0dd5acf232e2f9db3cc7639eb0d6) |
| 1 | `approve` 5 tUSD8 to PayGuard | `0xd314ad2b1d5d839932892beddbb061702043930d48f96dc3f46f5ba74b2561b3` | [view](https://explorer-test.qday.info/tx/0xd314ad2b1d5d839932892beddbb061702043930d48f96dc3f46f5ba74b2561b3) |
| 2 | `deposit` 5 tUSD8 | `0xc2c5235f714bcc62e262646f54585cb725e89848b352b3789b8b30e5d836c792` | [view](https://explorer-test.qday.info/tx/0xc2c5235f714bcc62e262646f54585cb725e89848b352b3789b8b30e5d836c792) |
| 3 | `registerPayee` by merchant | `0x1c2be2434489dc75956d08338c8ea43c0fbb9128b00e91e06a2e2e9c5bfc442c` | [view](https://explorer-test.qday.info/tx/0x1c2be2434489dc75956d08338c8ea43c0fbb9128b00e91e06a2e2e9c5bfc442c) |
| 4 | `authorizeAgent` with 5 tUSD8 cap | `0xdfc8c2d7eab7f4b7a20f601d2050e0d0d832c7c3569af89760c96c50048abf7f` | [view](https://explorer-test.qday.info/tx/0xdfc8c2d7eab7f4b7a20f601d2050e0d0d832c7c3569af89760c96c50048abf7f) |
| 5 | `createInvoice` for 2 tUSD8 | `0xb39200cf890084ebf053707f8d7eb5017e97732f7134e614368e2fb13ce9979b` | [view](https://explorer-test.qday.info/tx/0xb39200cf890084ebf053707f8d7eb5017e97732f7134e614368e2fb13ce9979b) |
| 6 | `payInvoice` by agent | `0x1190a27a98318addb9f2012955f0558ae98540901cc991920cb058836fe981ab` | [view](https://explorer-test.qday.info/tx/0x1190a27a98318addb9f2012955f0558ae98540901cc991920cb058836fe981ab) |
| 7 | `release` by merchant | `0x979fb3c4e580e7040ccce2b14deb6c7f643639f3bbaec937151e327568a8c331` | [view](https://explorer-test.qday.info/tx/0x979fb3c4e580e7040ccce2b14deb6c7f643639f3bbaec937151e327568a8c331) |

Raw hashes are also saved in `demo-tx.json`.

## Final on-chain state (RPC verified)

| Check | Result |
| --- | --- |
| `invoiceCount()` | `1` |
| Invoice 1 payer | `0xB6dE519D266F355C41fa4Dfe7b72112E30EF35AA` |
| Invoice 1 merchant | `0xc1c4E40c0841a6a4ab22488b161a95D220193F05` |
| Invoice 1 amount | `2000000` atomic = 2 tUSD8 |
| Invoice 1 payee hash | `0xc877a882470c157ad99f0adafb9978e745c34bb8ce43a36658695e85f73eb457` (`keccak256("Acme Studio")`) |
| Invoice 1 memo hash | `0x8c366e8016ac6df69296c1cf24d349a3e2deb81e830b3d47c2bbe8b93317b281` (`keccak256("invoice-2026-001")`) |
| Invoice 1 status | `3` = `Released` |
| Invoice 1 paidByAgent | `0xbF02Ed2Afc6BeE14BB989Eb8351c60030FDc2fd7` |
| Payer PayGuard balance | `3000000` atomic = 3 tUSD8 |
| Agent remaining budget | `3000000` atomic = 3 tUSD8 |
| Merchant tUSD8 balance | `2000000` atomic = 2 tUSD8 |
| PayGuard tUSD8 balance | `3000000` atomic = 3 tUSD8 |

## Demo recording

`PENDING` — record a 3–5 minute walkthrough showing the payer deposit, agent authorization, invoice creation, agent payment, merchant release, and explorer confirmation.

## Notes

- Early setup attempts included a 10 tUSD8 approval and a deposit that failed because the faucet supplies 5 tUSD8; the final successful demo uses 5 tUSD8 as recorded above.
- All addresses are throwaway Aevum Testnet addresses. No real funds, private keys, seed phrases, or production assets are used.
- No bounty has been claimed or paid yet; this is submission evidence only.
