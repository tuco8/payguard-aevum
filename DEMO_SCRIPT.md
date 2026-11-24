# Demo recording script (3–5 minutes)

Record your screen with audio. The easiest flow is terminal + Blockscout explorer; you do **not** need to import any private key into a browser wallet.

## Before recording

Open these in tabs:

1. <https://explorer-test.qday.info/address/0x55A357F9097Ab0C6F711EF23c46c6d32F0f1cFe2>
2. <https://explorer-test.qday.info/tx/0x923e5fcbc6fcc858152aebf2cb6eaefa91bd0dd5acf232e2f9db3cc7639eb0d6>
3. <https://explorer-test.qday.info/tx/0x979fb3c4e580e7040ccce2b14deb6c7f643639f3bbaec937151e327568a8c331>
4. This repo's `README.md` and `EVIDENCE.md`

Have `EVIDENCE.md` open so you can point at the transaction table.

## Narration

**0:00–0:30 — Problem**

> "AI agents need to pay for services, but a normal wallet gives them the whole balance and no way to prove the payee. PayGuard separates custody from execution: a human keeps the funds, an agent gets a scoped budget, and the merchant must be registered before an invoice can be paid."

**0:30–1:00 — Deployment**

Show the contract tab and deploy tx.

> "This is PayGuard deployed on Aevum Testnet, chain 44005, at 0x55A3...1cFe2. The constructor is bound to the official tUSD8 token. The deploy transaction is confirmed and funded entirely with free testnet tokens from the Builder Challenge Discord faucet."

**1:00–2:30 — Flow**

Walk through `EVIDENCE.md` rows 1–7, opening each explorer link briefly:

> "The payer approved and deposited five tUSD8. Then they authorized the agent with a five tUSD8 cap and a one-hour expiry. The merchant registered the identity hash for Acme Studio. The merchant created invoice one for two tUSD8, binding the payer, merchant, payee hash, memo hash, pay-by and release-by times. The agent called payInvoice — the contract checked the payee registration, active session, expiry, remaining budget and payer balance, then moved the funds into escrow. Finally the merchant called release and the two tUSD8 went to the merchant."

**2:30–3:30 — Final state / safety**

Run or show these RPC reads (PowerShell in the project folder):

```powershell
$cast='C:\Users\User\Documents\Default Project\mid-research\tools\foundry\cast.exe'
$rpc='https://rpc-test.qday.info'
$guard='0x55A357F9097Ab0C6F711EF23c46c6d32F0f1cFe2'
& $cast call $guard 'invoiceCount()(uint256)' --rpc-url $rpc
& $cast call $guard 'getInvoice(uint256)((address,address,uint256,bytes32,bytes32,uint64,uint64,uint64,uint8,address))' 1 --rpc-url $rpc
```

> "Invoice count is one. Status three means Released. The merchant field is the registered payee, the paid-by-agent field is our separate agent key, and the amount is two tUSD8. The payer still has three tUSD8 in the vault and the agent has three tUSD8 of budget left — so the cap was enforced, not bypassed."

**3:30–4:15 — Tests and docs**

Show `forge test -vv` output (13 passed) and the README.

> "Thirteen Foundry tests cover the failure cases too: double payment, unauthorized agent, expired session, budget cap, payee mismatch, zero amount, refunds, revocation, and withdrawal. The README maps the workflow to the judging criteria."

**4:15–4:45 — Close**

> "Everything runs on Aevum testnet with tUSD8, uses only free test tokens, and the full transaction trail is in EVIDENCE.md. PayGuard makes agent payments bounded, named, revocable, and escrowed."

## After recording

- Upload the video to YouTube (unlisted is fine) or Loom.
- Paste the link into `SUBMISSION.md` and the DoraHacks form.
- Keep the video under 5 minutes if possible; the requirement says 3–5 minutes.
