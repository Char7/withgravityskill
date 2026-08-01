[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('confirm', 'clarify', 'implement', 'revise')]
    [string]$Phase,

    [Parameter(Mandatory = $true)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $true)]
    [string]$PlanPath,

    [string]$ReviewPath,

    [string]$UnderstandingPath,

    [string]$ClarificationPath,

    [string]$ApprovalPath,

    [string]$ResponsePath,

    [string]$AgyPath,

    [string]$Model,

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

function Resolve-RepositoryOutput {
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

    $parent = Split-Path -Parent $resolved
    if (-not (Test-Path -LiteralPath $parent -PathType Container)) {
        throw "$Label parent directory does not exist: $parent"
    }

    if (Test-Path -LiteralPath $resolved) {
        throw "$Label already exists; use a new numbered handoff file: $resolved"
    }

    return $resolved
}

function Get-RepositoryRelativePath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $rootPrefix = $Root + [System.IO.Path]::DirectorySeparatorChar
    return $Path.Substring($rootPrefix.Length).Replace('\', '/')
}

function Assert-AlignmentApproval {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Plan,

        [Parameter(Mandatory = $true)]
        [string]$Understanding,

        [Parameter(Mandatory = $true)]
        [string]$Approval
    )

    $approvalText = Get-Content -Raw -LiteralPath $Approval
    if ($approvalText -notmatch '(?mi)^\s*status\s*:\s*APPROVED\s*$') {
        throw 'Approval file must contain: status: APPROVED'
    }

    $planMatch = [regex]::Match($approvalText, '(?mi)^\s*plan_sha256\s*:\s*([a-f0-9]{64})\s*$')
    $understandingMatch = [regex]::Match($approvalText, '(?mi)^\s*understanding_sha256\s*:\s*([a-f0-9]{64})\s*$')
    if (-not $planMatch.Success -or -not $understandingMatch.Success) {
        throw 'Approval file must contain plan_sha256 and understanding_sha256.'
    }

    $actualPlanHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Plan).Hash
    $actualUnderstandingHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $Understanding).Hash
    if (-not $actualPlanHash.Equals($planMatch.Groups[1].Value, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'PLAN.md changed after approval. Run the alignment gate again.'
    }
    if (-not $actualUnderstandingHash.Equals($understandingMatch.Groups[1].Value, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw 'The approved understanding changed after approval. Run the alignment gate again.'
    }
}

$resolvedRoot = [System.IO.Path]::GetFullPath($RepoRoot).TrimEnd('\', '/')
if (-not (Test-Path -LiteralPath $resolvedRoot -PathType Container)) {
    throw "Repository root does not exist: $resolvedRoot"
}

$resolvedPlan = Resolve-RepositoryFile -Root $resolvedRoot -Path $PlanPath -Label 'Plan file'
$resolvedReview = $null
$resolvedUnderstanding = $null
$resolvedClarification = $null
$resolvedApproval = $null
$resolvedResponse = $null

switch ($Phase) {
    'confirm' {
        if ([string]::IsNullOrWhiteSpace($ResponsePath)) {
            throw 'ResponsePath is required for the confirm phase.'
        }
        $resolvedResponse = Resolve-RepositoryOutput -Root $resolvedRoot -Path $ResponsePath -Label 'Understanding response'
    }
    'clarify' {
        if ([string]::IsNullOrWhiteSpace($UnderstandingPath) -or
            [string]::IsNullOrWhiteSpace($ClarificationPath) -or
            [string]::IsNullOrWhiteSpace($ResponsePath)) {
            throw 'UnderstandingPath, ClarificationPath, and ResponsePath are required for the clarify phase.'
        }
        $resolvedUnderstanding = Resolve-RepositoryFile -Root $resolvedRoot -Path $UnderstandingPath -Label 'Previous understanding file'
        $resolvedClarification = Resolve-RepositoryFile -Root $resolvedRoot -Path $ClarificationPath -Label 'Clarification file'
        $resolvedResponse = Resolve-RepositoryOutput -Root $resolvedRoot -Path $ResponsePath -Label 'Revised understanding response'
    }
    'implement' {
        if ([string]::IsNullOrWhiteSpace($UnderstandingPath) -or [string]::IsNullOrWhiteSpace($ApprovalPath)) {
            throw 'UnderstandingPath and ApprovalPath are required for the implement phase.'
        }
        $resolvedUnderstanding = Resolve-RepositoryFile -Root $resolvedRoot -Path $UnderstandingPath -Label 'Approved understanding file'
        $resolvedApproval = Resolve-RepositoryFile -Root $resolvedRoot -Path $ApprovalPath -Label 'Approval file'
        Assert-AlignmentApproval -Plan $resolvedPlan -Understanding $resolvedUnderstanding -Approval $resolvedApproval
    }
    'revise' {
        if ([string]::IsNullOrWhiteSpace($ReviewPath) -or
            [string]::IsNullOrWhiteSpace($UnderstandingPath) -or
            [string]::IsNullOrWhiteSpace($ApprovalPath)) {
            throw 'ReviewPath, UnderstandingPath, and ApprovalPath are required for the revise phase.'
        }
        $resolvedReview = Resolve-RepositoryFile -Root $resolvedRoot -Path $ReviewPath -Label 'Review file'
        $resolvedUnderstanding = Resolve-RepositoryFile -Root $resolvedRoot -Path $UnderstandingPath -Label 'Approved understanding file'
        $resolvedApproval = Resolve-RepositoryFile -Root $resolvedRoot -Path $ApprovalPath -Label 'Approval file'
        Assert-AlignmentApproval -Plan $resolvedPlan -Understanding $resolvedUnderstanding -Approval $resolvedApproval
    }
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

if (-not [string]::IsNullOrWhiteSpace($Model)) {
    if ($Model -notmatch '^[A-Za-z0-9][A-Za-z0-9._-]*$') {
        throw "Invalid Antigravity model ID: $Model"
    }

    $availableModels = @(& $resolvedAgy models) |
        ForEach-Object { $_.ToString().Trim() } |
        Where-Object { $_ -match '^[A-Za-z0-9][A-Za-z0-9._-]*$' }

    if ($LASTEXITCODE -ne 0) {
        throw "Unable to list Antigravity models; agy exited with code $LASTEXITCODE."
    }

    if ($availableModels -notcontains $Model) {
        throw "Antigravity model '$Model' is not available. Available models: $($availableModels -join ', ')"
    }
}

$planRelative = Get-RepositoryRelativePath -Root $resolvedRoot -Path $resolvedPlan
$reviewRelative = Get-RepositoryRelativePath -Root $resolvedRoot -Path $resolvedReview
$understandingRelative = Get-RepositoryRelativePath -Root $resolvedRoot -Path $resolvedUnderstanding
$clarificationRelative = Get-RepositoryRelativePath -Root $resolvedRoot -Path $resolvedClarification
$approvalRelative = Get-RepositoryRelativePath -Root $resolvedRoot -Path $resolvedApproval
$responseRelative = Get-RepositoryRelativePath -Root $resolvedRoot -Path $resolvedResponse

switch ($Phase) {
    'confirm' {
        $prompt = @"
Act as the planning counterpart for this task. Do not implement or edit any file.

Read $planRelative completely and inspect only the repository context needed to verify the plan. Return a concise Markdown understanding with exactly these headings:

# Understanding
## Objective
## Current behavior
## Expected behavior
## Planned changes
## Non-goals
## Acceptance criteria
## Edge cases
## Tests
## Assumptions and questions
## Readiness

Restate every acceptance criterion in your own words. Name likely files or code paths, but do not invent details. Under Readiness, write READY only when no material question or unsupported assumption remains; otherwise write NOT READY and list the blockers. Do not modify production code, handoff files, Git state, or any repository file. Output only the understanding document.
"@
    }
    'clarify' {
        $prompt = @"
Act as the planning counterpart for a clarification round. Do not implement or edit any file.

Read $planRelative, $understandingRelative, and $clarificationRelative completely. Return a revised, self-contained Markdown understanding with exactly these headings:

# Understanding
## Objective
## Current behavior
## Expected behavior
## Planned changes
## Non-goals
## Acceptance criteria
## Edge cases
## Tests
## Assumptions and questions
## Readiness

Resolve every Codex clarification explicitly and restate every acceptance criterion in your own words. Under Readiness, write READY only when no material question or unsupported assumption remains; otherwise write NOT READY and list the blockers. Do not modify production code, handoff files, Git state, or any repository file. Output only the revised understanding document.
"@
    }
    'implement' {
        $prompt = @"
Act as the implementation agent for this task.

Read $planRelative, $understandingRelative, and $approvalRelative completely. Implement only the approved plan and understanding.

Rules:
- Do not modify AGENTS.md unless the plan explicitly says the user requested it.
- Do not commit, push, checkout, reset, stash, clean, or modify .git.
- Preserve all pre-existing user changes.
- Do not expand scope or perform unrelated refactoring or formatting.
- Use terminal, web, and MCP tools only when required by the plan or its validation.
- If requirements conflict or information is insufficient, stop and report the blocker.
- Finish with a concise list of changed files and unverified items.
"@
    }
    'revise' {
        $prompt = @"
Act as the implementation agent for a review correction round.

Read $planRelative, $understandingRelative, $approvalRelative, and $reviewRelative completely. Fix only the actionable findings in the review while preserving the approved plan, understanding, and acceptance criteria.

Rules:
- Do not modify AGENTS.md unless the plan explicitly says the user requested it.
- Do not commit, push, checkout, reset, stash, clean, or modify .git.
- Preserve all pre-existing user changes.
- Do not expand scope or perform unrelated refactoring or formatting.
- Use terminal, web, and MCP tools only when required by the plan or review validation.
- If a finding cannot be fixed safely, stop and explain why.
- Finish with a concise mapping from each finding to its result.
"@
    }
}

$executionMode = if ($Phase -in @('confirm', 'clarify')) { 'plan' } else { 'accept-edits' }
$agyOptions = @(
    "--mode=$executionMode"
    '--dangerously-skip-permissions'
    "--print-timeout=$($TimeoutMinutes)m"
)

if (-not [string]::IsNullOrWhiteSpace($Model)) {
    $agyOptions += "--model=$Model"
}

$agyOptions += '--print'
$agyArguments = $agyOptions + @($prompt)

if ($DryRun) {
    [pscustomobject]@{
        Phase       = $Phase
        RepoRoot    = $resolvedRoot
        AgyPath     = $resolvedAgy
        PlanPath    = $planRelative
        ReviewPath  = $reviewRelative
        UnderstandingPath = $understandingRelative
        ClarificationPath = $clarificationRelative
        ApprovalPath = $approvalRelative
        ResponsePath = $responseRelative
        Model        = if ([string]::IsNullOrWhiteSpace($Model)) { '(Antigravity default)' } else { $Model }
        Permissions  = 'unrestricted (all Antigravity tool prompts auto-approved)'
        Arguments    = $agyOptions -join ' '
        Prompt      = $prompt.Trim()
    }
    exit 0
}

Push-Location -LiteralPath $resolvedRoot
try {
    if ($null -ne $resolvedResponse) {
        $agyOutput = @(& $resolvedAgy @agyArguments)
        if ($LASTEXITCODE -ne 0) {
            throw "Antigravity CLI exited with code $LASTEXITCODE."
        }

        $agyOutput | Write-Output
        $responseText = ($agyOutput | ForEach-Object { $_.ToString() }) -join [Environment]::NewLine
        if ([string]::IsNullOrWhiteSpace($responseText)) {
            throw 'Antigravity returned an empty alignment response.'
        }

        $utf8WithoutBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText(
            $resolvedResponse,
            $responseText.TrimEnd() + [Environment]::NewLine,
            $utf8WithoutBom
        )
    } else {
        & $resolvedAgy @agyArguments
        if ($LASTEXITCODE -ne 0) {
            throw "Antigravity CLI exited with code $LASTEXITCODE."
        }
    }
} finally {
    Pop-Location
}
