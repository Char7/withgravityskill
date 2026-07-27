[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('implement', 'revise')]
    [string]$Phase,

    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$PlanPath,

    [string]$ReviewPath,

    [string]$AgyPath,

    [ValidateRange(1, 120)]
    [int]$TimeoutMinutes = 20,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Resolve-RepositoryFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $candidate = if ([System.IO.Path]::IsPathRooted($Path)) {
        $Path
    } else {
        Join-Path $Root $Path
    }

    $resolved = [System.IO.Path]::GetFullPath($candidate)
    $rootPrefix = $Root + [System.IO.Path]::DirectorySeparatorChar

    if (-not $resolved.StartsWith($rootPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "$Label must be inside the repository root: $resolved"
    }

    if (-not (Test-Path -LiteralPath $resolved -PathType Leaf)) {
        throw "$Label does not exist: $resolved"
    }

    return $resolved
}

$resolvedRoot = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
    throw "Repository root does not exist: $resolvedRoot"
}

$resolvedPlan = Resolve-RepositoryFile -Root $resolvedRoot -Path $PlanPath -Label 'Plan file'
$resolvedReview = $null

if ($Phase -eq 'revise') {
    if ([string]::IsNullOrWhiteSpace($ReviewPath)) {
        throw 'ReviewPath is required for the revise phase.'
    }
    $resolvedReview = Resolve-RepositoryFile -Root $resolvedRoot -Path $ReviewPath -Label 'Review file'
}

if ([string]::IsNullOrWhiteSpace($AgyPath)) {
    $defaultAgy = Join-Path $env:LOCALAPPDATA 'agy\bin\agy.exe'
    if (Test-Path -LiteralPath $defaultAgy -PathType Leaf) {
        $AgyPath = $defaultAgy
    } else {
        $agyCommand = Get-Command agy -ErrorAction SilentlyContinue
        if ($null -eq $agyCommand) {
            throw 'Antigravity CLI was not found. Install agy or pass -AgyPath.'
        }
        $AgyPath = $agyCommand.Source
    }
}

$resolvedAgy = [System.IO.Path]::GetFullPath($AgyPath)
if (-not (Test-Path -LiteralPath $resolvedAgy -PathType Leaf)) {
    throw "Antigravity CLI does not exist: $resolvedAgy"
}

$rootPrefix = $resolvedRoot + [System.IO.Path]::DirectorySeparatorChar
$planRelative = $resolvedPlan.Substring($rootPrefix.Length).Replace('\', '/')
$reviewRelative = if ($null -ne $resolvedReview) {
    $resolvedReview.Substring($rootPrefix.Length).Replace('\', '/')
} else {
    $null
}

if ($Phase -eq 'implement') {
    $prompt = @"
Act as the implementation agent for this task.

Read $planRelative completely, then implement only that plan and its acceptance criteria.

Rules:
- Do not modify AGENTS.md unless the plan explicitly says the user requested it.
- Do not commit, push, checkout, reset, stash, clean, or modify .git.
- Preserve all pre-existing user changes.
- Do not expand scope or perform unrelated refactoring or formatting.
- Avoid terminal commands unless essential and already permitted.
- Never bypass permissions.
- If requirements conflict or information is insufficient, stop and report the blocker.
- Finish with a concise list of changed files and unverified items.
"@
} else {
    $prompt = @"
Act as the implementation agent for a review correction round.

Read $planRelative and $reviewRelative completely. Fix only the actionable findings in the review while preserving the original plan and acceptance criteria.

Rules:
- Do not modify AGENTS.md unless the plan explicitly says the user requested it.
- Do not commit, push, checkout, reset, stash, clean, or modify .git.
- Preserve all pre-existing user changes.
- Do not expand scope or perform unrelated refactoring or formatting.
- Avoid terminal commands unless essential and already permitted.
- Never bypass permissions.
- If a finding cannot be fixed safely, stop and explain why.
- Finish with a concise mapping from each finding to its result.
"@
}

$agyArguments = @(
    '--mode=accept-edits'
    "--print-timeout=$($TimeoutMinutes)m"
    '--print'
    $prompt
)

if ($DryRun) {
    [pscustomobject]@{
        Phase       = $Phase
        RepoRoot    = $resolvedRoot
        AgyPath     = $resolvedAgy
        PlanPath    = $planRelative
        ReviewPath  = $reviewRelative
        Arguments   = $agyArguments[0..2] -join ' '
        Prompt      = $prompt.Trim()
    }
    exit 0
}

Push-Location -LiteralPath $resolvedRoot
try {
    & $resolvedAgy @agyArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Antigravity CLI exited with code $LASTEXITCODE."
    }
} finally {
    Pop-Location
}
