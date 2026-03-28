---
description: Task completion workflow with code review, session handoff, ADR, and Git commit/push process.
---

# End

## How to use this skill

When the user invokes this skill (e.g., `/end`), the LLM will guide them through the task completion workflow.

**Example usage:**

```
/end
```

Your job as LLM is to:

1. **Review** code and design against project standards
2. **Update** documentation if needed
3. **Evaluate** lessons learned (autonomous decision)
4. **Generate** session handoff document
5. **Evaluate** if ADR is needed (autonomous decision)
6. **Commit** and push changes

---

## Workflow

### Step 1: Code Review

**Check against these files:**

- `docs/standards/code-review.md` — follow the code review checklist
- `docs/standards/design-review.md` — follow the design review checklist

**Instructions for LLM:**

1. Check if the above files exist and review their checklists
2. Ask the user to confirm all review points are addressed

---

### Step 2: Documentation Update

**Verify if updates are needed:**

1. Check if `README.md` needs updating (new features, changes in usage, etc.)
2. Check if `docs/` folder needs updating (refer to `docs/standards/contributing.md` for guidelines)

**Instructions for LLM:**

1. Review changes made during the session
2. Identify if README.md or docs/ require updates
3. If updates needed, make them before committing
4. If `docs/standards/contributing.md` exists, follow its documentation guidelines

---

### Step 3: Lessons Learned (Autonomous)

**Instructions for LLM:**

Do NOT ask the user. Evaluate autonomously whether a lessons-learned entry is warranted.

**Add entry to `docs/lessons-learned.md` ONLY when:**

- A bug or issue occurred that has appeared before (recurring problem)
- A problem was solved that has high probability of recurring and can be avoided by documenting the solution
- A non-obvious workaround was discovered that would save time in the future

**Do NOT add entry when:**

- The session was routine work without notable issues
- The problem was a one-off typo or trivial mistake
- The lesson is already documented in `docs/lessons-learned.md`

If adding an entry, briefly inform the user what was added and why.

---

### Step 4: Session Handoff

**Instructions for LLM:**

Generate a session handoff document at the end of every session.

1. Use the template from `docs/session-handoffs/yyyymmdd-template-session-handoff.md`
2. Save as `docs/session-handoffs/YYYY-MM-DD-<krotki-opis>.md`
   - Date from current session
   - Short description in Polish, kebab-case, no diacritics
   - Example: `2026-03-09-refaktoryzacja-kart-bottomsheets.md`
3. If multiple sessions on the same day — the short description differentiates them
4. Fill in all sections based on what happened during the session
5. The **short description** from the filename will be reused as the Git commit message (Step 6)

---

### Step 5: ADR (Conditional)

**Instructions for LLM:**

Evaluate autonomously whether an ADR is needed. Do NOT ask the user unless uncertain.

**Create ADR when the session included a decision about:**

- Architecture or system structure
- Technology or library choice
- Design pattern adoption or change
- Project convention change (coding style, naming, workflow)

**When creating ADR:**

1. Use the template from `docs/adr/ADR-000-template.md`
2. Determine the next ADR number by scanning existing files in `docs/adr/`
3. Save as `docs/adr/ADR-NNN-<krotki-tytul>.md`
   - Example: `ADR-001-wybor-komunikacji-miedzy-uslugami.md`
4. Fill in all sections based on the decision made during the session
5. **Mandatory:** Update the related document in `docs/` that is affected by this decision (e.g., `architecture.md`, `database.md`, `security.md`) — add a reference to the new ADR
6. Add a link to the ADR in the session handoff's "Decyzje" section

---

### Step 6: Git Commit

**Commit message format:**

```
<opis zmian po polsku>
```

**Rules:**

- **Description** = the short description from the session handoff filename, expanded if needed for clarity
- **No Polish diacritics**: a=a, c=c, e=e, l=l, n=n, o=o, s=s, z=z, z=z
- **No numbering prefix** — commit history provides natural ordering

**Instructions for LLM:**

1. Execute: `git add .`
2. Execute: `git commit -m "<opis>"`

**Example:**

```bash
git add .
git commit -m "Refaktoryzacja struktury kart i aktualizacja dokumentacji"
```

---

### Step 7: Git Push

**Instructions for LLM:**

1. Push directly to main: `git push origin main`
2. Confirm push was successful

---

## Completion Summary

After finishing all steps, provide the user with:

- ✅ Code review completed
- ✅ Documentation updated (if needed)
- ✅ Lessons learned: added / not needed (with reason)
- ✅ Session handoff: `<filename>`
- ✅ ADR: `<filename>` / not needed
- ✅ Commit: `<message>`
- ✅ Pushed to main

---

## Error Handling

**If any step fails:**

- Stop the workflow
- Explain the error to the user
- Ask how to proceed (fix and retry, or skip)
- Do not proceed to next steps until current step succeeds
