# Git Workflow

This document describes the Git workflow, branching strategy, and commit conventions for MOznoDS.

## Branch Strategy

### Main Branches

| Branch | Purpose |
|--------|---------|
| `main` | Production-ready code |
| `develop` | Integration branch for features |

### Feature Branches

```
<type>/<description>
```

**Types:**
- `feature/` – New functionality
- `fix/` – Bug fixes
- `refactor/` – Code restructuring
- `docs/` – Documentation changes
- `test/` – Test additions/changes
- `chore/` – Maintenance tasks

**Examples:**
```
feature/voice-calls
feature/file-upload
fix/websocket-reconnect
refactor/room-service
docs/api-reference
test/room-service-coverage
chore/update-dependencies
```

## Commit Messages

### Format (Conventional Commits)

```
<type>: <description>

[optional body]

[optional footer]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `test` | Adding or updating tests |
| `docs` | Documentation changes |
| `perf` | Performance improvement |
| `chore` | Maintenance (dependencies, configs) |
| `style` | Code style changes (formatting, no logic change) |

### Examples

```
feat: add file upload to chat messages

- Support images (jpg, png, gif) and documents (pdf, doc)
- Max file size: 10MB
- Files stored in S3-compatible storage
```

```
fix: resolve WebSocket reconnection issue

Connection was not properly re-established after network interruption.
Added exponential backoff retry logic.
```

```
refactor: extract room validation to service layer

Move validation logic from views to RoomService for better testability
and reusability.
```

```
test: add unit tests for RoomService

Coverage for create_room, add_participant, and remove_participant methods.
```

### Rules

1. **Use imperative mood** – "add feature" not "added feature"
2. **Don't capitalize first letter** – "add feature" not "Add feature"
3. **No period at the end** – "add feature" not "add feature."
4. **Keep subject line under 72 characters**
5. **Separate subject from body with blank line**

## Workflow

### Starting New Work

```bash
# Update develop branch
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/voice-calls
```

### Making Commits

```bash
# Stage changes
git add apps/calls/

# Commit with conventional message
git commit -m "feat: implement WebRTC signaling consumer"

# Push to remote
git push -u origin feature/voice-calls
```

### Creating Pull Request

```bash
# Ensure branch is up to date
git fetch origin
git rebase origin/develop

# Push and create PR
git push origin feature/voice-calls
# Then create PR via GitHub/GitLab UI
```

### Code Review

1. **Self-review** – Check your own changes before requesting review
2. **Small PRs** – Keep PRs focused and reviewable (< 400 lines ideal)
3. **Description** – Explain what and why, not how
4. **Tests** – Include tests for new functionality
5. **Documentation** – Update docs if needed

### Merging

```bash
# After approval, merge to develop
git checkout develop
git merge --no-ff feature/voice-calls
git push origin develop

# Delete feature branch
git branch -d feature/voice-calls
git push origin --delete feature/voice-calls
```

## Commit Frequency

### Good Practice

- **Commit often** – Small, logical units of work
- **Each commit should be buildable** – Tests should pass
- **Atomic commits** – One logical change per commit

### Example Commit Sequence

```
feat: add Room model
feat: add RoomService with create_room method
test: add unit tests for RoomService.create_room
feat: add CreateRoomView API endpoint
test: add API tests for room creation
docs: update API documentation for rooms
```

## Handling Conflicts

```bash
# Update your branch with latest develop
git fetch origin
git rebase origin/develop

# If conflicts occur, resolve them
# Edit conflicting files
git add <resolved-files>
git rebase --continue

# Force push (only for feature branches!)
git push --force-with-lease origin feature/voice-calls
```

## Reverting Changes

```bash
# Revert a specific commit
git revert <commit-hash>

# Revert last commit (keeping changes)
git reset --soft HEAD~1

# Revert last commit (discarding changes)
git reset --hard HEAD~1
```

## Git Hooks

Pre-commit hooks are configured to run automatically:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.4.4
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format
```

### Setup

```bash
# Install pre-commit
pip install pre-commit

# Install hooks
pre-commit install
```

### Bypassing Hooks (Emergency Only)

```bash
# Skip hooks for urgent fix
git commit --no-verify -m "fix: critical production issue"
```

**Warning:** Only use `--no-verify` in emergencies. Always run linters manually afterward.

## Release Process

### Version Tags

```bash
# Tag a release
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

### Changelog

Maintain `CHANGELOG.md` with notable changes:

```markdown
# Changelog

## [1.0.0] - 2024-01-15

### Added
- Group voice calls with WebRTC
- Text chat with file attachments
- Room management

### Fixed
- WebSocket reconnection issue

### Changed
- Improved file upload performance
```
