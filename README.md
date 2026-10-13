# git-wt

A small `git` subcommand for working with [git worktrees](https://git-scm.com/docs/git-worktree) without the ceremony. Create a worktree from a branch name, list what you have, and remove one when you're done.

```console
$ git wt create feature/login
🌳 Git Worktree Create
======================

Branch:     feature/login
Base:       HEAD
Repo root:  /Users/you/code/myproject

ℹ️  Creating worktree at: /Users/you/code/myproject/feature/login
✓ Worktree created
ℹ️  Running .worktree script...
✓ .worktree script completed

✓ Done!
```

## Why

`git worktree add` makes you invent a path, and then you have to set the new checkout up by hand — install dependencies, copy `.env`, and so on. `git wt` derives the path from the branch name and runs a per-repository hook so a new worktree is ready to work in immediately.

## Install

Requires `bash` 3.2+ and `git`. [`fzf`](https://github.com/junegunn/fzf) is optional and only used for interactive worktree selection.

```sh
git clone https://github.com/AranBorkum/git-wt.git
cd git-wt
make install
```

This installs to `~/.local` by default — the script to `~/.local/bin/git-wt` and its library to `~/.local/lib/git-wt`. Use a different location with `PREFIX`:

```sh
make install PREFIX=/usr/local
```

Make sure the `bin` directory is on your `PATH`. Because git treats any `git-*` executable on `PATH` as a subcommand, `git wt` then works from anywhere:

```sh
git wt --help
```

To remove it:

```sh
make uninstall
```

## Usage

### `git wt create <branch> [base]`

Creates a worktree at `<repo-root>/<branch>`, creating the branch if it doesn't exist. Slashes in the branch name become nested directories, so `feature/login` lands in `feature/login`.

```sh
git wt create feature/login              # branch from current HEAD
git wt create hotfix/bug-123 main        # branch from main
git wt create existing-branch --yes      # reuse a branch without prompting
```

If the branch already exists you'll be asked to confirm. When there's no terminal attached — in a script or CI — the command fails instead of hanging; pass `--yes` to proceed.

The worktree path is printed to stdout and everything else goes to stderr, so you can jump straight into the new checkout:

```sh
cd "$(git wt create feature/login)"
```

A shell function makes that nicer, since a child process can't change your shell's directory:

```sh
wtc() { cd "$(git wt create "$@")" || return; }
```

### `git wt list`

```console
$ git wt list
/Users/you/code/myproject                 main
/Users/you/code/myproject/feature/login   feature/login
/Users/you/code/myproject/spike           (detached)
```

Use `--paths` for bare paths, one per line, when scripting.

### `git wt delete [path-or-branch]`

Removes a worktree by path or branch name. With no argument it opens an `fzf` picker over every worktree except the main one.

```sh
git wt delete feature/login          # by branch name
git wt delete ../some/worktree       # by path
git wt delete                        # pick interactively
git wt delete feature/login --force  # discard uncommitted changes
```

Removing a worktree with uncommitted changes fails unless you pass `--force`. The main worktree is never removed.

## The `.worktree` hook

If an executable file named `.worktree` exists at the repository root, `git wt create` runs it inside the newly created worktree. It's the place to put whatever setup a fresh checkout needs:

```sh
#!/usr/bin/env bash
set -euo pipefail

# Config that isn't tracked in git
cp "$(git rev-parse --git-common-dir)/../.env" .env

npm install
```

The hook runs with the new worktree as its working directory. If it fails you get a warning rather than an error — the worktree is already created and usable, so a broken hook doesn't cost you the checkout. Commit the hook to share setup with everyone on the repo, or add it to `.git/info/exclude` to keep it personal.

## Layout

```
git-wt              # entrypoint: resolves lib/, dispatches commands
lib/
  version.sh        # single source of truth for the version
  output.sh         # message helpers (all write to stderr)
  git.sh            # git plumbing wrappers
  create.sh         # git wt create
  delete.sh         # git wt delete
  list.sh           # git wt list
tests/
  helper.sh         # assertions and the scratch-repo fixture
  run.sh            # runs every test file
  test_*.sh         # one file per area
```

## Development

```sh
make check      # lint + format check + tests  (run this before pushing)
make test       # tests only
make lint       # shellcheck
make fmt        # format in place with shfmt
make help       # list targets
```

Tests need only `bash` and `git` — no test framework to install. Each test runs against a throwaway repository in a temp directory, created and torn down around it. CI runs the suite on Ubuntu and macOS, the latter covering bash 3.2.

### Releasing

The version lives in one place, `lib/version.sh`. Bump it and merge to `master`; CI reads it, verifies the CLI reports the same value, runs the tests, then pushes a `v<version>` tag and creates a GitHub release. The workflow is idempotent — pushes that don't change the version are a no-op, so it won't try to re-tag an existing release.

## License

[MIT](LICENSE)
