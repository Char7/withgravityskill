---
name: withgravityskill
description: Explicit Codex-to-Antigravity coding workflow with a mandatory plan-alignment gate. Use when the user invokes $withgravityskill or explicitly asks Codex to choose SOLO versus PAIR, have Antigravity restate and clarify a Codex plan before implementation, implement approved larger changes with all tool permission prompts auto-approved, and have Codex review and test the resulting diff. Use PAIR only in trusted repositories, preserve existing work, and do not modify AGENTS.md unless the user explicitly requests it.
---

# With Gravity

Act as the planner and reviewer. Use Antigravity CLI only as the implementation agent when PAIR mode is selected. Treat agents implemented inside the repository as product code, not as Codex or Antigravity workers.

## Respect instruction scope

- Read and follow every applicable `AGENTS.md` as repository guidance.
- Do not add this workflow to, or otherwise modify, any `AGENTS.md` unless the user explicitly requests that change.
- Apply this skill only to the task that invoked `$withgravityskill`.
- Follow the user's latest explicit mode selection over this skill.
- Do not start Codex subagents unless the user explicitly requests them.

## Select a mode

Parse `SOLO`, `PAIR`, or `AUTO` from the user's invocation. Default to `AUTO`.

Parse an optional Antigravity model as `MODEL=<model-id>`. If omitted, let Antigravity use its configured default. A model selection applies only when PAIR runs; if AUTO selects SOLO, state that the requested Antigravity model was not used. Do not guess or silently substitute an unavailable model.

Use SOLO when the change is small, low-risk, normally limited to one or two files, and does not alter public APIs, authentication, authorization, database schemas, concurrency, transactions, or architecture.

Use PAIR when the work spans several files or modules, adds a feature, performs structural refactoring, is mechanically large, or affects a high-risk area.

For AUTO, inspect only enough context to make the choice, then state the selected mode and a one-sentence reason. Do not use PAIR merely because Antigravity is available.

## Perform the common preflight

1. Resolve the repository root and read applicable instructions.
2. Run `git status --short` before editing.
3. Preserve all pre-existing changes. Never reset, checkout, clean, stash, or overwrite them.
4. If the task is likely to overlap pre-existing edits, stop and ask the user before proceeding.
5. Define the goal, scope, acceptance criteria, risks, and relevant test commands.
6. Never commit or push unless the user explicitly requests it.
7. Before PAIR begins, state that Antigravity will run unrestricted with every tool permission prompt auto-approved. Continue without another confirmation because invoking this skill authorizes that mode.

## Run SOLO

1. Inspect the smallest relevant code path.
2. Make the smallest production change that satisfies the task.
3. Add or update focused tests when warranted.
4. Run relevant tests, lint, type checks, or builds.
5. Review the complete task diff for correctness, regressions, security, and scope creep.
6. Report changed files, validation results, and remaining uncertainty.

## Run PAIR

### 1. Create the handoff

Create a unique task ID such as `login-retry-20260727-1430`. Store task-only artifacts at:

```text
.codex/handoffs/<task-id>/PLAN.md
.codex/handoffs/<task-id>/UNDERSTANDING-01.md
.codex/handoffs/<task-id>/CLARIFICATION-01.md
.codex/handoffs/<task-id>/UNDERSTANDING-02.md
.codex/handoffs/<task-id>/APPROVED.md
.codex/handoffs/<task-id>/REVIEW.md
```

Create clarification and understanding files only when that round occurs. A second clarification round uses `CLARIFICATION-02.md` and `UNDERSTANDING-03.md`. Never overwrite an alignment artifact.

Do not overwrite an existing task directory. `PLAN.md` must include:

- goal and current behavior
- desired behavior
- root cause for a bug, when known
- relevant files and code paths
- implementation requirements
- explicit non-goals and prohibited changes
- acceptance criteria and edge cases
- tests and validation commands
- known risks

Do not put secrets or credentials in handoff files. Do not edit production code during this planning phase.

### 2. Run the plan-alignment gate

Invoke Antigravity in plan mode and capture its first understanding:

```powershell
& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass `
  -File '<skill-dir>\scripts\invoke-antigravity.ps1' `
  -Phase confirm `
  -RepoRoot '<repository-root>' `
  -PlanPath '.codex\handoffs\<task-id>\PLAN.md' `
  -ResponsePath '.codex\handoffs\<task-id>\UNDERSTANDING-01.md'
```

When the user specified `MODEL`, append `-Model '<model-id>'` to every Antigravity phase. Inspect the response against `PLAN.md`; do not accept Antigravity's `READY` statement by itself. Approve only when all of these hold:

- the objective, current behavior, and desired behavior match the plan
- every acceptance criterion is accurately restated
- proposed files and code paths are plausible and within scope
- non-goals, prohibited changes, edge cases, and tests are preserved
- assumptions are supported and no material question remains
- applicable repository instructions are not contradicted

If alignment fails, write specific mismatches and questions to `CLARIFICATION-01.md`, then invoke:

```powershell
& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass `
  -File '<skill-dir>\scripts\invoke-antigravity.ps1' `
  -Phase clarify `
  -RepoRoot '<repository-root>' `
  -PlanPath '.codex\handoffs\<task-id>\PLAN.md' `
  -UnderstandingPath '.codex\handoffs\<task-id>\UNDERSTANDING-01.md' `
  -ClarificationPath '.codex\handoffs\<task-id>\CLARIFICATION-01.md' `
  -ResponsePath '.codex\handoffs\<task-id>\UNDERSTANDING-02.md'
```

Allow at most two clarification rounds. For the second round, use the latest understanding as input and the `-02` clarification and `-03` response paths. If material uncertainty remains after two rounds, stop and ask the user; do not implement.

When alignment passes, calculate SHA-256 for `PLAN.md` and the accepted understanding, then create `APPROVED.md` with exactly these fields:

```text
status: APPROVED
plan_sha256: <64-character SHA-256>
understanding_sha256: <64-character SHA-256>
```

Use `Get-FileHash -Algorithm SHA256 -LiteralPath '<path>'` to calculate each hash. The wrapper rejects implementation if either approved file changes. If the plan must change after approval, abandon that approval, create a new task ID, and run alignment again.

### 3. Invoke Antigravity

Run the bundled wrapper from the repository root:

```powershell
& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass `
  -File '<skill-dir>\scripts\invoke-antigravity.ps1' `
  -Phase implement `
  -RepoRoot '<repository-root>' `
  -PlanPath '.codex\handoffs\<task-id>\PLAN.md' `
  -UnderstandingPath '.codex\handoffs\<task-id>\UNDERSTANDING-<accepted-round>.md' `
  -ApprovalPath '.codex\handoffs\<task-id>\APPROVED.md'
```

Resolve `<skill-dir>` to this skill's installation directory before running it. `ExecutionPolicy Bypass` applies only to loading this local wrapper in that one PowerShell process. The wrapper validates an explicit model against `agy models`, verifies the approval hashes, uses `--mode=accept-edits` plus `--dangerously-skip-permissions`, and rejects handoff paths outside the repository.

Wait for Antigravity to finish. Do not edit the same files concurrently. Antigravity must not pause for tool approvals because the wrapper auto-approves them all; treat any remaining pause as a non-permission blocker and report its exact output.

### 4. Review independently

Do not trust Antigravity's summary as validation.

1. Run `git status --short` and `git diff --stat`.
2. Read the complete relevant diff while distinguishing pre-existing changes.
3. Compare the implementation to `PLAN.md` and every acceptance criterion.
4. Check correctness, error handling, compatibility, regressions, security, edge cases, test coverage, and scope creep.
5. Run the relevant tests, lint, type checks, and build commands.
6. Record actionable findings in `REVIEW.md`, including priority, file or location, impact, expected behavior, and verification method.

### 5. Request corrections

When review findings exist, invoke:

```powershell
& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass `
  -File '<skill-dir>\scripts\invoke-antigravity.ps1' `
  -Phase revise `
  -RepoRoot '<repository-root>' `
  -PlanPath '.codex\handoffs\<task-id>\PLAN.md' `
  -UnderstandingPath '.codex\handoffs\<task-id>\UNDERSTANDING-<accepted-round>.md' `
  -ApprovalPath '.codex\handoffs\<task-id>\APPROVED.md' `
  -ReviewPath '.codex\handoffs\<task-id>\REVIEW.md'
```

When a model was selected, append the same `-Model '<model-id>'` used for implementation. Omit `-Model` throughout when the user did not select one.

Allow at most two Antigravity correction rounds. Re-review and rerun validation after every round. In PAIR mode, do not silently take over implementation; if two rounds fail, stop and report the remaining blockers unless the user authorizes Codex to fix them.

## Finish safely

Report:

1. selected mode and reason
2. selected Antigravity model, or `Antigravity default`; report `not used` for SOLO
3. permission mode: `unrestricted` for PAIR or `not used` for SOLO
4. task ID for PAIR mode
5. alignment result, accepted understanding file, and clarification rounds
6. changed files and behavior
7. tests and checks run, with results
8. review findings and correction rounds
9. remaining risks or unverified behavior

Do not claim success unless the relevant acceptance criteria pass. Ask before deleting handoff artifacts, and delete only artifacts created for the current task.

## Invocation examples

```text
$withgravityskill AUTO: Add retry handling to the API client.
$withgravityskill SOLO: Correct the validation message and run its focused test.
$withgravityskill PAIR: Refactor authentication and add regression coverage.
$withgravityskill PAIR MODEL=gemini-3.6-flash-high: Refactor authentication and add regression coverage.
```
