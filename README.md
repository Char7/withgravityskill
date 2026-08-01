# With Gravity Skill

Personal Codex skill สำหรับ workflow แบบ **Codex วางแผน → Codex กับ Antigravity ยืนยันความเข้าใจ → Antigravity เขียนโค้ด → Codex ตรวจสอบ** โดยเลือกทำงานแบบ Codex เพียงตัวเดียวได้อัตโนมัติเมื่องานมีขนาดเล็ก

## Workflow

```text
User request
    │
    ▼
Codex selects AUTO / SOLO / PAIR
    │
    ├─ SOLO ─► Codex implements, tests, and reviews
    │
    └─ PAIR ─► Codex plans ─► Antigravity restates the plan
                              ├─► Codex approves alignment
                              ├─► Antigravity implements
                              └─► Codex reviews and tests
```

## Modes

| Mode | Behavior | Recommended for |
| --- | --- | --- |
| `AUTO` | Codex selects SOLO or PAIR from scope and risk | Default usage |
| `SOLO` | Codex plans, implements, tests, and reviews | Small, low-risk changes |
| `PAIR` | Codex plans, verifies Antigravity's understanding, then Antigravity implements and Codex reviews | Multi-file, structural, or high-risk changes |

## Requirements

- Codex desktop app, CLI, or IDE extension with personal skill support
- [Google Antigravity CLI](https://antigravity.google/docs/cli-install) available as `agy`
- Windows PowerShell
- A Git repository for the target project

The bundled wrapper looks for Antigravity at:

```text
%LOCALAPPDATA%\agy\bin\agy.exe
```

## Installation

Clone this repository into the personal Codex skills directory:

```powershell
git clone https://github.com/Char7/withgravityskill.git `
  "$env:USERPROFILE\.codex\skills\withgravityskill"
```

If `CODEX_HOME` points somewhere else, place the repository under its `skills` directory instead. Open a new Codex task or restart Codex after installation.

## Usage

Let the skill choose the mode:

```text
$withgravityskill AUTO: Add retry handling to the API client.
```

Force Codex-only execution:

```text
$withgravityskill SOLO: Correct the login validation message and run its focused test.
```

Force the planning and handoff workflow:

```text
$withgravityskill PAIR: Refactor authentication and add regression coverage.
```

Select an Antigravity model explicitly:

```text
$withgravityskill PAIR MODEL=gemini-3.6-flash-high: Refactor authentication and add regression coverage.
```

`MODEL=<model-id>` is optional. When omitted, Antigravity uses its configured default. The wrapper validates an explicit model against the output of `agy models` before implementation starts. If AUTO selects SOLO, Codex reports that the Antigravity model was not used.

List the models currently available to your Antigravity account with:

```powershell
agy models
```

## PAIR execution

In PAIR mode, Codex:

1. Reads applicable repository instructions and checks the working tree.
2. Creates a task-specific plan under `.codex/handoffs/<task-id>/PLAN.md`.
3. Runs Antigravity in plan mode and captures a structured `UNDERSTANDING-01.md` response.
4. Checks that response against every requirement and allows at most two clarification rounds.
5. Creates `APPROVED.md` with SHA-256 hashes of the accepted plan and understanding.
6. Invokes Antigravity with `--mode=accept-edits`, `--dangerously-skip-permissions`, and the selected `--model` when provided.
7. Reviews the resulting Git diff independently and runs relevant checks.
8. Writes actionable findings to `REVIEW.md` and allows at most two correction rounds.

## Plan Alignment Gate

PAIR does not let Antigravity start implementation immediately. Antigravity must first restate:

- objective and expected behavior
- planned files and code paths
- non-goals and prohibited changes
- every acceptance criterion
- edge cases and validation commands
- assumptions, questions, and readiness

Codex compares that response with `PLAN.md`. When the response is incomplete or inaccurate, Codex writes a numbered clarification and asks Antigravity for a new, self-contained understanding. Implementation starts only after Codex approves the alignment. The wrapper verifies that neither the plan nor the accepted understanding changed after approval.

Typical PAIR artifacts:

```text
.codex/handoffs/<task-id>/
|-- PLAN.md
|-- UNDERSTANDING-01.md
|-- CLARIFICATION-01.md       # only when needed
|-- UNDERSTANDING-02.md       # only when needed
|-- APPROVED.md
`-- REVIEW.md
```

## Safety guardrails

- PAIR runs Antigravity unrestricted and auto-approves every tool permission prompt. Use it only with trusted repositories and task inputs.
- Codex reviews the resulting diff after execution, but that review cannot undo deleted data, credential exposure, network actions, or other external side effects that already occurred.
- Antigravity must pass the plan-alignment gate before implementation; self-reported readiness is not sufficient.
- Alignment is limited to two clarification rounds to prevent an unbounded Codex-Antigravity loop.
- Does not modify `AGENTS.md` unless explicitly requested.
- Preserves pre-existing user changes and stops on likely overlap.
- Rejects handoff files outside the repository root.
- Prevents Codex and Antigravity from editing concurrently.
- Does not commit, push, reset, checkout, stash, or clean without explicit authorization.
- Does not claim success until the relevant acceptance criteria and checks pass.

## Repository structure

```text
withgravityskill/
├─ README.md
├─ SKILL.md
├─ agents/
│  └─ openai.yaml
└─ scripts/
   └─ invoke-antigravity.ps1
```

## Updating

```powershell
git -C "$env:USERPROFILE\.codex\skills\withgravityskill" pull
```
