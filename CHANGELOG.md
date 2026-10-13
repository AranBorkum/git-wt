# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[semantic versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `git wt list` for showing each worktree and its checked-out branch, with
  `--paths` for scripting.
- `git wt delete` now accepts a path or branch name, so it no longer requires
  `fzf` for non-interactive use. Added `--force` for worktrees with
  uncommitted changes.
- `git wt version`, `--help` on every subcommand, and `--yes` on `create` for
  non-interactive use.
- Test suite (`make test`), shellcheck and shfmt targets, and CI running on
  Ubuntu and macOS.
- `make install` / `make uninstall`, README, MIT license.
- Release workflow that tags `v<version>` from `lib/version.sh`.

### Changed

- Split the single script into `lib/` modules by concern.
- `create` prints only the worktree path to stdout and sends all progress
  messages to stderr, so `cd "$(git wt create x)"` works.
- The `.worktree` hook now runs with the new worktree as its working
  directory rather than wherever the command was invoked.

### Fixed

- `git wt create` passed the command name through as the branch name, so it
  created a worktree called `create` and ignored the branch you asked for.
- `git wt create` with no branch name now prints usage and exits 2 instead of
  creating a stray worktree.
- Invalid branch names, missing base branches, and paths that would escape the
  repository root are rejected before any worktree is created.
- `delete` refuses to remove the main worktree instead of failing obscurely.

## [0.1.0]

Initial version: `create` and `delete` in a single script.
