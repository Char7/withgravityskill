---
name: withgravityskill
description: Explicit Codex-to-Antigravity coding workflow. Use when the user invokes $withgravityskill or explicitly asks Codex to choose SOLO versus PAIR, plan a coding task, have Antigravity CLI implement larger changes, and have Codex review and test the resulting diff. Keep repository agents distinct from development agents, preserve existing work, and do not modify AGENTS.md unless the user explicitly requests it.
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
.codex/handoffs/<task-id>/REVIEW.md
```

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

### 2. Invoke Antigravity

Run the bundled wrapper from the repository root:

```powershell
& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass `
  -File '<skill-dir>\scripts\invoke-antigravity.ps1' `
  -Phase implement `
  -RepoRoot '<repository-root>' `
  -PlanPath '.codex\handoffs\<task-id>\PLAN.md'
```

Resolve `<skill-dir>` to this skill's installation directory before running it. `ExecutionPolicy Bypass` applies only to loading this local wrapper in that one PowerShell process; it does not bypass Codex or Antigravity permissions. The wrapper uses `--mode=accept-edits`, never uses `--dangerously-skip-permissions`, and rejects handoff paths outside the repository.

Wait for Antigravity to finish. Do not edit the same files concurrently. If Antigravity cannot proceed because approval is required, report the exact request; do not bypass permissions.

### 3. Review independently

Do not trust Antigravity's summary as validation.

1. Run `git status --short` and `git diff --stat`.
2. Read the complete relevant diff while distinguishing pre-existing changes.
3. Compare the implementation to `PLAN.md` and every acceptance criterion.
4. Check correctness, error handling, compatibility, regressions, security, edge cases, test coverage, and scope creep.
5. Run the relevant tests, lint, type checks, and build commands.
6. Record actionable findings in `REVIEW.md`, including priority, file or location, impact, expected behavior, and verification method.

### 4. Request corrections

When review findings exist, invoke:

```powershell
& 'powershell.exe' -NoProfile -ExecutionPolicy Bypass `
  -File '<skill-dir>\scripts\invoke-antigravity.ps1' `
  -Phase revise `
  -RepoRoot '<repository-root>' `
  -PlanPath '.codex\handoffs\<task-id>\PLAN.md' `
  -ReviewPath '.codex\handoffs\<task-id>\REVIEW.md'
```

Allow at most two Antigravity correction rounds. Re-review and rerun validation after every round. In PAIR mode, do not silently take over implementation; if two rounds fail, stop and report the remaining blockers unless the user authorizes Codex to fix them.

## Finish safely

Report:

1. selected mode and reason
2. task ID for PAIR mode
3. changed files and behavior
4. tests and checks run, with results
5. review findings and correction rounds
6. remaining risks or unverified behavior

Do not claim success unless the relevant acceptance criteria pass. Ask before deleting handoff artifacts, and delete only artifacts created for the current task.

## Invocation examples

```text
$withgravityskill AUTO: Add retry handling to the API client.
$withgravityskill SOLO: Correct the validation message and run its focused test.
$withgravityskill PAIR: Refactor authentication and add regression coverage.
```
