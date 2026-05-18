---
name: commit
description: Stage and commit changes using conventional commits format
disable-model-invocation: true
allowed-tools: shell(git:*)
---

# Commit Changes

Create a conventional commit for the current changes. Do NOT ask for confirmation - proceed directly with the commit.

## Process

1. **Analyze changes**: Run `git status` and `git diff` to understand all modifications
2. **Group logically**: If changes span multiple unrelated concerns, identify coherent subsets that form a logical whole
3. **Stage selectively**: Use `git add <specific-files>` to stage only the files that belong together in one commit
4. **Write commit message**: Create a conventional commit message following the format below
5. **Commit**: Execute the commit without asking for confirmation
6. **Report**: Show the user what was committed

If there are remaining unstaged changes after the first commit, repeat the process for the next logical group.

## Conventional Commits Format

```
<type>[optional scope]: <description>

[optional body]
```

### Types

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that do not affect the meaning of the code (white-space, formatting, missing semi-colons, etc)
- **refactor**: A code change that neither fixes a bug nor adds a feature
- **perf**: A code change that improves performance
- **test**: Adding missing tests or correcting existing tests
- **build**: Changes that affect the build system or external dependencies
- **ci**: Changes to CI configuration files and scripts
- **chore**: Other changes that don't modify src or test files

### Rules

- Use lowercase for type and description
- Description should be imperative mood ("add feature" not "added feature")
- No period at the end of the description
- Keep the first line under 72 characters
- Use scope when the change is specific to a component or module
- Add body for complex changes that need explanation

### Examples

```
feat(auth): add login with OAuth2 support
```

```
fix: resolve race condition in data fetching

The previous implementation could cause duplicate requests
when the component unmounted during an active fetch.
```

## Important

- Do NOT use `git add -A` or `git add .` - always stage specific files
- Do NOT ask the user for confirmation before committing
- Do NOT use --no-verify or skip any hooks
- Do NOT add any author or co-author information to commit messages
- Do NOT include include `Co-authored-by`!
- If there are no changes to commit, inform the user and stop