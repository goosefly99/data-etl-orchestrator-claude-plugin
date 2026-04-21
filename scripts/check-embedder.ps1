# Temporary stopgap — remove once sibling kb_embedder_health lands in
# agent-knowledgebase v0.7.0. Tracking: data-etl-orchestrator ROADMAP.md FIELD-11.
#
# Usage:
#   .\check-embedder.ps1 [-Url <url>] [-TimeoutSec <seconds>]
#
# Emits a single JSON line to stdout:
#   {"up": true,  "latency_ms": 42,   "endpoint": "http://..."}
#   {"up": false, "latency_ms": null, "endpoint": "http://...", "error": "..."}
# Exit code 0 if up, exit code 1 if down.

param(
    [string]$Url = 'http://localhost:11434/api/tags',
    [int]$TimeoutSec = 5
)

$sw = [System.Diagnostics.Stopwatch]::StartNew()

$up = $false
$latencyMs = $null
$errorMsg = $null

try {
    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -TimeoutSec $TimeoutSec -ErrorAction Stop
    $sw.Stop()
    $latencyMs = [int]$sw.Elapsed.TotalMilliseconds

    if ($response.StatusCode -ge 200 -and $response.StatusCode -lt 300) {
        $up = $true
    } else {
        $errorMsg = "unexpected HTTP status $($response.StatusCode)"
    }
} catch {
    $sw.Stop()
    $latencyMs = $null
    $errorMsg = $_.Exception.Message
}

if ($up) {
    $result = [ordered]@{
        up         = $true
        latency_ms = $latencyMs
        endpoint   = $Url
    }
    $result | ConvertTo-Json -Compress
    exit 0
} else {
    $result = [ordered]@{
        up         = $false
        latency_ms = $null
        endpoint   = $Url
        error      = $errorMsg
    }
    $result | ConvertTo-Json -Compress
    exit 1
}
