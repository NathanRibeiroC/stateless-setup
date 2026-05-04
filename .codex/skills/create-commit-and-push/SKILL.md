---
name: create-commit-and-push
description: Create, finalize, validate, and push Git commits using the active repository's documented conventions. Use when the user asks Codex to commit, close a commit, finalize changes, push, or otherwise publish local work, especially in repositories with AGENTS.md, HISTORICAL.md, commit prefixes, CI requirements, or project-specific Git rules.
---

# Create Commit and Push

## Workflow

1. Read the active repository instructions before committing.
   - Prefer `AGENTS.md` and nested instructions when present.
   - Follow project-specific commit prefixes, validation commands, history requirements, and push rules.

2. Inspect the worktree.
   - Run `git status --short`.
   - Review staged and unstaged diffs enough to understand what will be committed.
   - Never revert, reset, clean, or discard changes unless the user explicitly asks.
   - Do not include unrelated user changes by accident. Split commits when pending changes represent different ideas.

3. Classify the commit using the repository convention.
   - Use `feat: <feature description>` for a feature.
   - Use `fix: <descricao da correcao>` for a bug fix or regression.
   - Use `config: <configuration description>` for configuration, environment, or tooling changes.
   - Use `doc: <mudancas feitas>` for documentation.
   - If the repository defines additional prefixes, prefer the repository rules.

4. Prepare the index deliberately.
   - Stage only the files that belong to the commit.
   - Use separate commits for unrelated documentation/configuration/feature changes.
   - If a file has mixed unrelated edits, pause and ask before using partial staging unless the user already requested that exact split.

5. Validate before pushing.
   - Run the repository's documented validation command when available.
   - For `exploration_project`, run `mise exec -- bin/ci` before push.
   - If validation fails, do not push automatically. Summarize the failing check and ask whether to fix it.

6. Create the commit.
   - Use a descriptive subject with the selected prefix.
   - Include the footer exactly:

```text
Assisted by Codex: <versao atual>
```

7. Push only after a successful validation or explicit user override.
   - Run `git push`.
   - If network access is sandboxed, request escalation for the push.
   - Report the commit SHA, validation result, and remote update.

## Project-Specific Notes

For `exploration_project`, preserve these rules:

- Before push, replicate GitHub Actions locally with `mise exec -- bin/ci`.
- If `mise exec -- bin/ci` fails, stop before push and ask whether to implement the fix.
- Record relevant feature/history/decision changes in `HISTORICAL.md` when the project instructions require it.
- Keep commits small and reviewable.
- Preserve local-only or unrelated user changes.
