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
- **summary**: imperative mood, lowercase, no trailing period, ideally ≤ 72 characters
- **body**: optional, explain what and why; use `-` bullet points for multiple changes
- **breaking changes**: add `!` after the type/scope (e.g. `feat!: ...`) or a `BREAKING CHANGE:` footer

Examples:

```
feat(ui): add repository list page
fix(api): handle GitHub rate limit responses
build(deps): add hooks_riverpod and flutter_hooks
```
