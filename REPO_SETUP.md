# Publish the repo safely

Prerequisites: Git and GitHub CLI installed, and `gh auth login` completed in a browser. **Do not paste tokens or passwords into chat.**

From this folder (`aevum-bounty\payguard`), run:

```powershell
git init -b main
git check-ignore -v .env
git add .
git status --short
```

Confirm two things before committing:

1. `.env` appears in `git check-ignore` output.
2. `git status --short` does **not** list `.env`, `out/`, `cache/`, or `broadcast/`.

If that looks right:

```powershell
git commit -m "PayGuard: budgeted agent payments on Aevum"
gh repo create payguard-aevum --public --source=. --remote=origin --push
```

If the repo name is taken, choose another, e.g.:

```powershell
gh repo create payguard-aevum-testnet --public --source=. --remote=origin --push
```

After pushing, copy the HTTPS URL printed by `gh` and paste it into `SUBMISSION.md` and the DoraHacks form.

## If authentication opens a browser

Choose **GitHub.com → HTTPS → Login through your web browser**. Press Enter when `gh` shows the one-time code. Cancel and retry if it asks you to paste a personal access token — browser login is cleaner.

## Never publish

- `.env`
- private keys or seed phrases
- `out/`, `cache/`, `broadcast/` local build artifacts
- your MetaMask recovery phrase

The project's `.gitignore` already excludes the sensitive local files; the checks above verify it before the first commit.
