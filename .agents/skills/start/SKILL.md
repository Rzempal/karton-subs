---
name: start
description: Session initialization workflow. Loads project context, reads last session handoff, clarifies the task, and produces an implementation plan before coding.
---

# Start

## How to use this skill

When the user invokes this skill (e.g., `/start`), they will provide a goal and tasks in any format.

**Example usage:**

```
/start
## Task
Refaktoryzacja systemu kart i bottom sheets

## Additional context
Dotyczy komponentów w src/components/cards/
```

Your job as LLM is to:

1. **Load** project context (in priority order)
2. **Read** the latest session handoff
3. **Understand** the task and clarify ambiguities
4. **Propose** an implementation plan
5. **Wait** for acceptance before coding

---

## Workflow

### Step 1: Load Project Context

**Read files in this order (stop if file doesn't exist, move to next):**

1. `AGENTS.md` — system rules, project map, navigation
2. `README.md` — project entry point
3. `docs/architecture.md` — modules, dependencies, data flow

**Then, only if relevant to the stated task:**

4. Specific `docs/` files matching the task domain (e.g., `docs/database.md` for DB work, `docs/design.md` for UI work)
5. `docs/standards/conventions.md` — coding conventions
6. `docs/standards/contributing.md` — contribution guidelines

**Instructions for LLM:**

- Follow the priority order — do not read everything blindly
- Read only what is needed to understand the task scope
- Do not list what you read to the user unless asked

---

### Step 2: Load Last Session Handoff

**Instructions for LLM:**

1. Check `docs/session-handoffs/` for the most recent file (by date in filename)
2. If found, read it and extract:
   - **Otwarte kwestie** — present them to the user as a brief list
   - **Kontekst** — use it to understand continuity with previous work
3. If not found or directory doesn't exist — skip silently, this is a fresh project

**Present to user:**

```
Ostatnia sesja (YYYY-MM-DD): <krótki opis>
Otwarte kwestie:
- <kwestia 1>
- <kwestia 2>
```

This gives the user a chance to pick up an open item or proceed with their new task.

---

### Step 3: Understand the Task

**Apply this process:**

1. **Repeat** the goal and tasks in your own words
2. **Identify scope** — which files, modules, components are involved
3. **Check project files** first before asking questions — don't guess, don't ask what you can look up
4. **Ask clarifying questions** only for genuine ambiguities
5. **Flag risks or conflicts** with existing architecture, conventions, or open decisions (ADRs)

---

### Step 4: Implementation Plan

**Present a plan in this format:**

```
## Plan
1. [Step] → weryfikacja: [jak sprawdzić że krok się udał]
2. [Step] → weryfikacja: [jak sprawdzić]
...

Pliki do modyfikacji: <lista>
Ryzyko: <jeśli istnieje>
```

**Rules:**

- Each step must have a verification criterion (aligned with Goal-Driven Execution from AGENTS.md)
- Stay within the agreed scope — if you spot issues outside scope, report them separately
- Keep the plan minimal and actionable

---

### Step 5: Wait for Acceptance

**Do NOT start implementation until the user explicitly accepts the plan.**

If the user modifies the plan — update and re-present. Repeat until accepted.

---

## Error Handling

- If critical context files are missing (no README.md, no AGENTS.md) — inform the user and ask how to proceed
- If the task conflicts with existing ADRs — flag it before planning
- If the task scope is unclear after reading all available context — ask, don't assume
