# shellcheck shell=bash
#
# Thin wrappers around the git plumbing git-wt relies on. Keeping these in one
# place makes the command modules readable and the behaviour easy to test.

# Fail unless the current directory is inside a git repository.
require_git_repo() {
	if ! git rev-parse --git-dir >/dev/null 2>&1; then
		die "Not in a git repository"
	fi
}

# Print the directory that worktrees are created beside.
#
# For a bare repository that is the repository directory itself; for a regular
# checkout or an existing worktree it is the parent of the common git dir, so
# every worktree of a repo lands in the same place regardless of where the
# command was run from.
repo_root() {
	if [ "$(git rev-parse --is-bare-repository 2>/dev/null || echo false)" = "true" ]; then
		pwd
		return 0
	fi

	local git_dir
	git_dir=$(git rev-parse --git-common-dir)
	if [[ "$git_dir" != /* ]]; then
		git_dir=$(cd "$git_dir" && pwd)
	fi
	dirname "$git_dir"
}

# Succeed if the named local branch exists.
branch_exists() {
	git show-ref --verify --quiet "refs/heads/$1"
}

# Succeed if the given revision can be resolved.
rev_exists() {
	git rev-parse --verify --quiet "$1" >/dev/null 2>&1
}

# Print the absolute path of every registered worktree, one per line.
#
# Parsed from --porcelain rather than the human-readable listing because paths
# containing spaces survive it intact.
worktree_paths() {
	git worktree list --porcelain | sed -n 's/^worktree //p'
}
