# With Gravity Skill

Personal Codex skill สำหรับ workflow แบบ **Codex วางแผน → Antigravity เขียนโค้ด → Codex ตรวจสอบ** โดยเลือกทำงานแบบ Codex เพียงตัวเดียวได้อัตโนมัติเมื่องานมีขนาดเล็ก

## Workflow

```text
User request
    │
    ▼
Codex selects AUTO / SOLO / PAIR
    │
    ├─ SOLO ─► Codex implements, tests, and reviews
    │
    └─ PAIR ─► Codex plans ─► Antigravity implements
                              └► Codex reviews and tests
```

## Modes

| Mode | Behavior | Recommended for |
| --- | --- | --- |
| `AUTO` | Codex selects SOLO or PAIR from scope and risk | Default usage |
| `SOLO` | Codex plans, implements, tests, and reviews | Small, low-risk changes |
| `PAIR` | Codex plans, Antigravity implements, Codex reviews | Multi-file, structural, or high-risk changes |

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

## PAIR execution

In PAIR mode, Codex:

1. Reads applicable repository instructions and checks the working tree.
2. Creates a task-specific plan under `.codex/handoffs/<task-id>/PLAN.md`.
3. Invokes Antigravity with `--mode=accept-edits`.
4. Reviews the resulting Git diff independently and runs relevant checks.
5. Writes actionable findings to `REVIEW.md` and allows at most two correction rounds.

## Safety guardrails

- Does not modify `AGENTS.md` unless explicitly requested.
- Preserves pre-existing user changes and stops on likely overlap.
- Never invokes `--dangerously-skip-permissions`.
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
