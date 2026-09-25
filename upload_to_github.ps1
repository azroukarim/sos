# ============================================================
#  upload_to_github.ps1 - Enigma2 Cython Compiler v4.1 (uploader)
#  Uploads the new tool files to your GitHub repo:
#    https://github.com/azroukarim/sos  (branch: main)
#
#  Files uploaded:
#    1. compile_tool.sh     (replaces the old v2)
#    2. restore_backup.sh   (new)
#    3. quick_compile.sh    (new)
#
#  HOW TO GET A TOKEN (once):
#    GitHub -> Settings -> Developer settings -> Personal access
#    tokens -> Tokens (classic) -> Generate new token (classic)
#    -> tick ONLY:  "repo"  -> Generate  (name it: upload-enigma2)
#    Copy the token (it starts with ghp_...)
# ============================================================

$Repo   = "azroukarim/sos"
$Branch = "main"
$Root   = $PSScriptRoot

$Token = $env:GITHUB_TOKEN
if (-not $Token) {
    $Token = Read-Host "Enter your GitHub token (ghp_...)"
}
if (-not $Token) {
    Write-Host "ERROR: No token provided." -ForegroundColor Red
    exit 1
}

$Headers = @{
    "Authorization" = "token $Token"
    "Accept"        = "application/vnd.github+json"
    "User-Agent"    = "enigma2-cython-compiler"
}

$Files = @("compile_tool.sh", "restore_backup.sh", "quick_compile.sh")

foreach ($File in $Files) {
    $LocalPath = Join-Path $Root $File
    if (-not (Test-Path $LocalPath)) {
        Write-Host "[SKIP] $File not found locally" -ForegroundColor Yellow
        continue
    }

    $ContentB64 = [Convert]::ToBase64String([IO.File]::ReadAllBytes($LocalPath))

    # 1) Does the file already exist in the repo? (GET)
    $Sha = $null
    try {
        $Existing = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/contents/$File`?ref=$Branch" `
                                      -Headers $Headers -Method GET
        $Sha = $Existing.sha
        Write-Host "[INFO] $File exists in repo (will UPDATE)" -ForegroundColor Cyan
    } catch {
        Write-Host "[INFO] $File is new (will CREATE)" -ForegroundColor Cyan
    }

    # 2) Create or update via PUT
    $Body = @{
        message = "Update $File - Enigma2 Cython Compiler v4.1"
        content = $ContentB64
        branch  = $Branch
    } | ConvertTo-Json
    if ($Sha) { $Body = @{ message = "Update $File - v4.1"; content = $ContentB64; branch = $Branch; sha = $Sha } | ConvertTo-Json }

    try {
        $Result = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/contents/$File" `
                                    -Headers $Headers -Method PUT -Body $Body
        $DownloadUrl = "https://raw.githubusercontent.com/$Repo/$Branch/$File"
        Write-Host "[OK] $File  ->  $DownloadUrl" -ForegroundColor Green
        $Result.content.download_url | Out-Null
    } catch {
        Write-Host "[FAIL] $File : $($_.Exception.Message)" -ForegroundColor Red
        if ($_.ErrorDetails.Message) { Write-Host $_.ErrorDetails.Message -ForegroundColor Red }
    }
}

Write-Host ""
Write-Host "Done. Verify: https://github.com/$Repo" -ForegroundColor Green
Write-Host ""
Write-Host "On the box, the compile one-liner is:"
Write-Host "  wget --no-check-certificate https://raw.githubusercontent.com/$Repo/$Branch/quick_compile.sh -O /tmp/quick_compile.sh && /bin/sh /tmp/quick_compile.sh compile <plugin>"
Write-Host "Restore one-liner:"
Write-Host "  /bin/sh /tmp/quick_compile.sh restore <plugin>"