param(
    [string]$CastPath = "C:\Users\User\Documents\Default Project\mid-research\tools\foundry\cast.exe",
    [switch]$SkipFunding
)

$ErrorActionPreference = "Stop"
$envPath = Join-Path (Split-Path -Parent $PSScriptRoot) ".env"
if (-not (Test-Path -LiteralPath $envPath)) { throw "Missing .env. Copy .env.example and fill testnet-only keys first." }

$values = @{}
foreach ($line in Get-Content -LiteralPath $envPath) {
    if (-not $line -or $line.StartsWith("#")) { continue }
    $idx = $line.IndexOf("=")
    if ($idx -gt 0) {
        $values[$line.Substring(0, $idx).Trim()] = $line.Substring($idx + 1).Trim()
    }
}

$rpc = $values["RPC_URL"]
$token = $values["TUSD8"]
$payerKey = $values["PRIVATE_KEY"]
$merchantKey = $values["MERCHANT_PRIVATE_KEY"]
$agentKey = $values["AGENT_PRIVATE_KEY"]
$payer = $values["PAYER_ADDRESS"]
$merchant = $values["MERCHANT_ADDRESS"]
$agent = $values["AGENT_ADDRESS"]
$guard = $values["PAYGUARD_ADDRESS"]

if (-not $rpc -or -not $token -or -not $guard -or -not $payerKey -or -not $merchantKey -or -not $agentKey) {
    throw "Required values missing from .env (RPC_URL, TUSD8, PAYGUARD_ADDRESS, PRIVATE_KEY, MERCHANT_PRIVATE_KEY, AGENT_PRIVATE_KEY)."
}
if (-not (Test-Path -LiteralPath $CastPath)) { throw "cast.exe not found at $CastPath" }

$payeeHash = & $CastPath keccak "Acme Studio"
$memoHash = & $CastPath keccak "invoice-2026-001"
$agentExpiry = [DateTimeOffset]::UtcNow.AddHours(1).ToUnixTimeSeconds()
$payBy = [DateTimeOffset]::UtcNow.AddMinutes(30).ToUnixTimeSeconds()
$releaseBy = [DateTimeOffset]::UtcNow.AddHours(2).ToUnixTimeSeconds()

$txs = [ordered]@{}

function Send-Step {
    param(
        [string]$Name,
        [string]$Target,
        [string]$Signature,
        [string[]]$ArgsList,
        [string]$Key
    )
    $cmd = @("send", $Target, $Signature) + $ArgsList + @("--rpc-url", $rpc, "--private-key", $Key, "--legacy")
    $output = (& $CastPath @cmd 2>&1 | Out-String)
    $hashMatch = [regex]::Match($output, "0x[a-fA-F0-9]{64}")
    if (-not $hashMatch.Success) { throw "$Name failed or hash not found. Output:`n$output" }
    $hash = $hashMatch.Value
    $txs[$Name] = $hash
    Write-Host "$Name`: $hash"
    Write-Host "  https://explorer-test.qday.info/tx/$hash"
}

Write-Host "PayGuard demo on Aevum Testnet (chain 44005)"
Write-Host "Contract: $guard"

if (-not $SkipFunding) {
    Send-Step "approve" $token "approve(address,uint256)" @($guard, "5000000") $payerKey
    Send-Step "deposit" $guard "deposit(uint256)" @("5000000") $payerKey
}
Send-Step "registerPayee" $guard "registerPayee(bytes32)" @($payeeHash) $merchantKey
Send-Step "authorizeAgent" $guard "authorizeAgent(address,uint256,uint64)" @($agent, "5000000", "$agentExpiry") $payerKey
Send-Step "createInvoice" $guard "createInvoice(address,address,uint256,uint64,uint64,bytes32,bytes32)" @($payer, $merchant, "2000000", "$payBy", "$releaseBy", $payeeHash, $memoHash) $merchantKey
Send-Step "payInvoice" $guard "payInvoice(uint256)" @("1") $agentKey
Send-Step "release" $guard "release(uint256)" @("1") $merchantKey

$outPath = Join-Path (Split-Path -Parent $PSScriptRoot) "demo-tx.json"
$txs | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $outPath
Write-Host "Saved transaction hashes to $outPath"
