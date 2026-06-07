# Commit Rules & Style Guide

To maintain a clean, readable, and structured commit history, all future contributions, Pull Requests (PRs), and Technical Commits (TCs) must strictly adhere to the following commit style based on the **Conventional Commits** standard.

## 1. Commit Message Format

Each commit message consists of a **header**, an optional **body**, and an optional **footer**.

```
<type>(<optional scope>): <subject>

[optional body]

[optional footer(s)]
```

### Example
```text
fix(repost): resolve infinite repost loop caused by missing user_id mapping

- Added snake_case fallback `user_id` across 8 different user verification checks.
- Ensures the UI correctly recognizes the author of a repost wrapper from GCP MySQL.
- Prevents duplicate API calls by properly validating cached repost IDs.
```

## 2. Allowed Types
The `<type>` must be one of the following:

- **`feat`**: A new feature for the user or app.
- **`fix`**: A bug fix.
- **`docs`**: Documentation only changes (e.g., `README.md`, `documents/`).
- **`style`**: Changes that do not affect the meaning of the code (white-space, formatting, UI color tweaks, etc).
- **`refactor`**: A code change that neither fixes a bug nor adds a feature (e.g., restructuring files, renaming variables).
- **`perf`**: A code change that improves performance.
- **`test`**: Adding missing tests or correcting existing tests.
- **`chore`**: Changes to the build process, dependency updates (e.g., `pubspec.lock`), or auxiliary tools.

## 3. The Subject Line (`<subject>`)
- Must use the **imperative, present tense**: "change" not "changed" nor "changes" (e.g., `fix: resolve issue`, `feat: implement login`).
- Do NOT capitalize the first letter of the subject unless it's a proper noun.
- No dot (`.`) at the end of the subject line.
- Try to keep it under **70 characters**.

## 4. The Body
- **Mandatory for complex changes** or bug fixes that require context.
- Use **bullet points** (`- `) to break down multiple changes within the same commit.
- Explain **what** and **why** (context/rationale), rather than just *how* the code was changed.
- Wrap the body text at **100 characters**.

## 5. Pull Requests (PR) & Technical Commits (TC) Rules
- **Squash Commits:** If your branch has multiple messy "WIP" or "checkpoint" commits, they must be squashed into clean, logical Conventional Commits before merging.
- **Isolate Changes:** Do not mix formatting/style changes with feature additions in the same commit. Keep them separated.
- **Test Before Committing:** Never commit broken code or untested features to the main branch. Ensure your local `flutter analyze` and builds succeed.
