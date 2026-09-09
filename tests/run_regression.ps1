param(
    [string]$Target = "tests",
    [int]$TimeoutSeconds = 60
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$godotPath = Join-Path $projectRoot "tools/Godot-4.7.2/Godot_v4.7.2-stable_win64.exe"
$targetPath = Join-Path $projectRoot $Target
$resultRoot = Join-Path $projectRoot "work/test-results"

if (-not (Test-Path -LiteralPath $godotPath -PathType Leaf)) {
    throw "Godot executable not found: $godotPath"
}
if (-not (Test-Path -LiteralPath $targetPath)) {
    throw "Test target not found: $targetPath"
}

New-Item -ItemType Directory -Force -Path $resultRoot | Out-Null
$tests = if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
    @(Get-Item -LiteralPath $targetPath)
} else {
    @(Get-ChildItem -LiteralPath $targetPath -Recurse -File -Filter "*_test.gd" | Sort-Object FullName)
}

if ($tests.Count -eq 0) {
    throw "No *_test.gd files found under $Target"
}

$passed = 0
$failed = [System.Collections.Generic.List[object]]::new()
$startedAt = Get-Date

foreach ($test in $tests) {
    $relativePath = $test.FullName.Substring($projectRoot.Length + 1).Replace("\", "/")
    $safeName = $relativePath.Replace("/", "__").Replace(".gd", "")
    $engineLog = Join-Path $resultRoot "$safeName.engine.log"
    $capturedLog = Join-Path $resultRoot "$safeName.log"

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo.FileName = $godotPath
    $process.StartInfo.WorkingDirectory = $projectRoot
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    $arguments = @("--headless", "--path", $projectRoot, "--log-file", $engineLog, "--script", "res://$relativePath")
    $process.StartInfo.Arguments = ($arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' }) -join " "

    [void]$process.Start()
    $stdoutTask = $process.StandardOutput.ReadToEndAsync()
    $stderrTask = $process.StandardError.ReadToEndAsync()
    $completed = $process.WaitForExit($TimeoutSeconds * 1000)
    if (-not $completed) {
        $process.Kill()
        $process.WaitForExit()
    }
    $output = $stdoutTask.Result + $stderrTask.Result
    Set-Content -LiteralPath $capturedLog -Value $output

    $hasPassMarker = $output -match '(?m)_TEST:\s*PASS\s*$'
    $hasFailMarker = $output -match '(?m)_TEST:\s*FAIL\s*$'
    $hasScriptError = $output -match '(?m)^SCRIPT ERROR:'
    # Some Windows Godot builds return exit code 1 after a successful headless
    # test because engine shutdown/logging fails. The test marker is authoritative.
    $isPassing = $completed -and $hasPassMarker -and -not $hasFailMarker -and -not $hasScriptError
    if ($isPassing) {
        $passed++
    } else {
        $reason = if (-not $completed) { "timeout" } elseif ($hasFailMarker) { "test failure" } elseif ($hasScriptError) { "script error" } elseif (-not $hasPassMarker) { "missing PASS marker (exit $($process.ExitCode))" } else { "exit $($process.ExitCode)" }
        $failed.Add([pscustomobject]@{ Test = $relativePath; Reason = $reason; Log = $capturedLog })
    }
}

$duration = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 1)
Write-Host "Tests: $($tests.Count)  Passed: $passed  Failed: $($failed.Count)  Time: ${duration}s"
foreach ($failure in $failed) {
    $relativeLog = $failure.Log.Substring($projectRoot.Length + 1)
    Write-Host "FAIL  $($failure.Test)  [$($failure.Reason)]  $relativeLog"
}

if ($failed.Count -gt 0) { exit 1 }
exit 0
