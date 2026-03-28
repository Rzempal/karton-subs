---
description: Workflow to update main branch and merge a feature branch into it, including cleanup options.
---

---

name: Merge
description: Workflow to update main branch and merge a feature branch into it, including cleanup options
---

# Git Merge to Main

## How to use this skill

When the user invokes this skill (e.g., `/merge` or `/merge-main`), the LLM will guide them through the process of merging their work into the production/main branch.

**Example usage:**

/merge

Your job as LLM is to:

1. **Ensure** the workspace is clean.
2. **identify** the feature branch.
3. **Update** the `main` branch.
4. **Merge** the feature branch into `main`.
5. **Push** changes to remote.
6. **Cleanup** old branches.

---

## Workflow

### Step 1: Pre-checks & Identification

**Instructions for LLM:**

1. Check current status: `git status --porcelain`
   - If output is not empty: **STOP**. Ask user to commit or stash changes (refer to `/end` workflow if needed).
2. Get current branch name: `git branch --show-current`
3. Identify Feature Branch:
   - If current branch is `main`: Ask user "Which branch would you like to merge into main?" and list available branches.
   - If current branch is NOT `main`: Confirm with user: "Do you want to merge branch '[CurrentBranch]' into 'main'?"
4. Wait for user confirmation.

---

### Step 2: Update Main

**Instructions for LLM:**

1. Execute: `git checkout main`
2. Execute: `git pull origin main`
3. Verify `main` is up to date and clean.

---

### Step 3: Merge

**Instructions for LLM:**

1. Execute: `git merge --no-ff <FeatureBranch>`
   - *Note: `--no-ff` is used to create a merge commit and preserve branch topology.*
2. Check for conflicts:
   - **If conflicts occur:**
     - The merge will stop.
     - Tell the user: "Merge conflicts detected."
     - Instruct user to resolve conflicts in their editor.
     - Tell user to run `git commit` to conclude the merge after resolving.
     - **STOP** workflow here until user confirms conflicts are resolved and committed.

---

### Step 4: Git Push

**Instructions for LLM:**

1. Execute: `git push origin main`
2. Confirm successful push.

---

### Step 5: Cleanup (Optional)

**Instructions for LLM:**

1. Ask user: "Do you want to delete the local branch '<FeatureBranch>'?"
2. If USER says YES:
   - Execute: `git branch -d <FeatureBranch>`
   - If it fails (due to unmerged check logic?), verify if it's safe to force delete or ask user.
3. Ask user: "Do you want to delete the remote branch 'origin/<FeatureBranch>'?"
4. If USER says YES:
   - Execute: `git push origin --delete <FeatureBranch>`

---

## Completion Summary

After finishing all steps, provide the user with:

- ✅ Main branch checked out and updated
- ✅ Branch `<FeatureBranch>` merged into main
- ✅ Changes pushed to remote
- ✅ Branch cleanup performed (if requested)

---

## Error Handling

**If any step fails:**

- Stop the workflow
- Explain the error to the user
- Ask how to proceed
