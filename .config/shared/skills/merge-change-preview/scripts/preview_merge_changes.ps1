param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$TargetRef,

    [Parameter(Mandatory = $true, Position = 1)]
    [string]$SourceRef,

    [Parameter(Mandatory = $false)]
    [switch]$Patch
)

$ErrorActionPreference = "Stop"

function Fail([string]$Message, [int]$Code = 1) {
    Write-Error $Message
    exit $Code
}

& git rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "Error: must run inside a git repository."
}

& git rev-parse --verify "$TargetRef^{commit}" *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "Error: target ref not found: $TargetRef"
}

& git rev-parse --verify "$SourceRef^{commit}" *> $null
if ($LASTEXITCODE -ne 0) {
    Fail "Error: source ref not found: $SourceRef"
}

$mergeTreeSha = ""
$mergeHelp = (& git merge-tree -h 2>&1 | Out-String)
if ($LASTEXITCODE -eq 0 -and $mergeHelp -match "--write-tree") {
    $mergeTreeOutput = (& git merge-tree --write-tree $TargetRef $SourceRef 2>&1 | Out-String).TrimEnd()
    if ($LASTEXITCODE -ne 0) {
        Fail "Error: merge simulation reported conflicts; resolve conflicts to know final exact changes.`n$mergeTreeOutput" 2
    }

    $treeMatch = [regex]::Match($mergeTreeOutput, '(?m)^[0-9a-f]{40}$')
    if ($treeMatch.Success) {
        $mergeTreeSha = $treeMatch.Value
    }
    elseif ($mergeTreeOutput -match '^[0-9a-f]{40}$') {
        $mergeTreeSha = $mergeTreeOutput
    }
}

if ([string]::IsNullOrWhiteSpace($mergeTreeSha)) {
    $tmpWorktree = Join-Path ([System.IO.Path]::GetTempPath()) ("merge-preview-" + [Guid]::NewGuid().ToString("N"))
    try {
        & git worktree add --quiet --detach $tmpWorktree $TargetRef *> $null
        if ($LASTEXITCODE -ne 0) {
            Fail "Error: failed to create temporary worktree."
        }

        $mergeOutput = (& git -C $tmpWorktree merge --no-commit --no-ff --quiet $SourceRef 2>&1 | Out-String).TrimEnd()
        if ($LASTEXITCODE -ne 0) {
            Fail "Error: merge simulation reported conflicts; resolve conflicts to know final exact changes.`n$mergeOutput" 2
        }

        $mergeTreeSha = (& git -C $tmpWorktree write-tree | Out-String).Trim()
    }
    finally {
        & git -C $tmpWorktree merge --abort *> $null
        & git worktree remove --force $tmpWorktree *> $null
        if (Test-Path $tmpWorktree) {
            Remove-Item -Recurse -Force $tmpWorktree -ErrorAction SilentlyContinue
        }
    }
}

if ([string]::IsNullOrWhiteSpace($mergeTreeSha)) {
    Fail "Error: unable to determine merge tree hash."
}

Write-Output "== Raw commits (ancestry: $TargetRef..$SourceRef) =="
& git --no-pager log --oneline "$TargetRef..$SourceRef"
Write-Output ""

Write-Output "== Effective commits (cherry-pick equivalents filtered) =="
& git --no-pager log --oneline --right-only --cherry-pick "$TargetRef...$SourceRef"
Write-Output ""

Write-Output "== Net file changes from merge result =="
& git diff --quiet $TargetRef $mergeTreeSha
if ($LASTEXITCODE -eq 0) {
    Write-Output "(none)"
}
else {
    & git --no-pager diff --name-status $TargetRef $mergeTreeSha
}
Write-Output ""

Write-Output "== Net change summary =="
& git --no-pager diff --shortstat $TargetRef $mergeTreeSha
Write-Output ""

if ($Patch.IsPresent) {
    Write-Output "== Full patch (target vs simulated merge result) =="
    & git --no-pager diff $TargetRef $mergeTreeSha
}
