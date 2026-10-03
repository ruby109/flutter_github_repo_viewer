# AGENTS.md

## Commit Messages

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<optional scope>): <short summary>

<optional body>

<optional footer>
```

- **type**: one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`
- **scope**: optional, the affected area (e.g. `deps`, `ui`, `api`)
- **summary**: imperative mood, lowercase, no trailing period; the whole subject line must be ≤ 72 characters
- **body**: optional, explain what and why; use `-` bullet points for multiple changes
- **breaking changes**: add `!` after the type/scope (e.g. `feat!: ...`) or a `BREAKING CHANGE:` footer

Examples:

```
feat(ui): add repository list page
fix(api): handle GitHub rate limit responses
build(deps): add hooks_riverpod and flutter_hooks
```

The `commit-msg` hook (`scripts/check-commit-msg.sh`) rejects subjects that don't match this format.

## Setup

Git hooks are managed by [lefthook](https://lefthook.dev). Install it once per machine and enable the hooks once per clone:

```sh
brew install lefthook   # or: npm i -g lefthook / go install github.com/evilmartians/lefthook/v2@latest
lefthook install
```

Hooks also work from GUI git clients such as Fork: `scripts/lefthook-rc.sh` (the `rc` in `lefthook.yml`) restores PATH from your login shell when `flutter` is missing. Make sure your shell startup files (`~/.zprofile` or `~/.zshrc`) put Flutter on PATH.

## Code Quality Checks

All Dart code must be formatted with `dart format`, pass `dart analyze --fatal-infos` with no issues, and pass `flutter test`.

Use `dart analyze`, not `flutter analyze`: only `dart analyze` runs analyzer plugins, and [riverpod_lint](https://pub.dev/packages/riverpod_lint) is enabled as a plugin in `analysis_options.yaml`.

| Stage | Where | What runs |
|---|---|---|
| pre-commit | `lefthook.yml` | `dart format` on staged `.dart` files (re-staged automatically), then `dart analyze --fatal-infos` |
| commit-msg | `lefthook.yml` | Conventional Commits check |
| pre-push | `lefthook.yml` | `flutter test --exclude-tags golden` |
| After Claude edits a `.dart` file | `.claude/settings.json` → `.claude/hooks/dart-post-edit.sh` | `dart format` and `dart analyze --fatal-infos` on that file; issues are reported back to Claude |
| CI (push / PR) | `.github/workflows/ci.yml` | format check, analyze, test (excluding goldens) |
| PR opened / updated / reopened / ready for review | `.github/workflows/golden.yml` | golden tests on Linux; diffs uploaded as the `golden-failures` artifact |

Local hooks can be skipped with `--no-verify`; CI is the gate that must pass before merging.

## Golden Tests

Golden (snapshot) tests use Flutter's built-in `matchesGoldenFile` with the `testGoldens` helper in `test/helpers/golden_devices.dart`, which renders at iPhone 17, iPhone SE, iPad and Android phone sizes and tags tests `golden`. They run only on Linux CI because font rendering differs between operating systems, so never commit golden files generated on macOS: push the branch and run `scripts/update-goldens.sh` to have CI regenerate and commit them. The project skill `.claude/skills/golden-test/SKILL.md` has the full workflow.

## Agent Skills

Official Flutter and Dart agent skills are vendored for Claude Code (`.claude/skills/`) and other agents (`.agents/skills/`), pinned in `skills-lock.json`. Don't edit them by hand (except the project-owned `golden-test` skill); update with:

```sh
npx skills update -p
```
