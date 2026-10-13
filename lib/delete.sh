# shellcheck shell=bash
#
# `git wt delete` — remove a worktree, chosen interactively or by name.

delete_usage() {
	cat >&2 <<'EOF'
Usage: git wt delete [path-or-branch]

Removes a git worktree. With no argument, pick one from a list (requires fzf).

Options:
  -f, --force   Remove even if the worktree has local changes
  -h, --help    Show this help
EOF
}

# Resolve a user-supplied path or branch name to a registered worktree path.
resolve_worktree() {
	local wanted="$1" path
	local resolved=""

	if [ -d "$wanted" ]; then
		resolved=$(cd "$wanted" && pwd)
	fi

	while IFS= read -r path; do
		[ -n "$path" ] || continue
		if [ "$path" = "$wanted" ] || [ "$path" = "$resolved" ] ||
			[ "$(basename "$path")" = "$wanted" ]; then
			printf '%s\n' "$path"
			return 0
		fi
	done < <(worktree_paths)

	return 1
}

# Let the user choose a worktree with fzf, excluding the main worktree (which
# `git worktree remove` refuses to delete anyway).
select_worktree() {
	command -v fzf >/dev/null 2>&1 ||
		die "fzf is required to choose a worktree interactively; pass a path or branch instead"

	local paths main
	main=$(worktree_paths | head -n 1)
	paths=$(worktree_paths | tail -n +2)

	[ -n "$paths" ] || die "No worktrees to delete (only the main worktree at $main)"

	local choice
	choice=$(printf '%s\n' "$paths" | fzf --prompt='Delete worktree> ' --height=40% --reverse) || return 1
	[ -n "$choice" ] || return 1
	printf '%s\n' "$choice"
}

delete_worktree() {
	local force=false

	while [ $# -gt 0 ]; do
		case "$1" in
			-h | --help)
				delete_usage
				return 0
				;;
			-f | --force)
				force=true
				shift
				;;
			--)
				shift
				break
				;;
			-*)
				error "Unknown option: $1"
				delete_usage
				return 2
				;;
			*)
				break
				;;
		esac
	done

	require_git_repo

	local target
	if [ $# -ge 1 ]; then
		target=$(resolve_worktree "$1") || die "No worktree matching: $1"
	else
		target=$(select_worktree) || die "Aborted."
	fi

	local main
	main=$(worktree_paths | head -n 1)
	if [ "$target" = "$main" ]; then
		die "Refusing to remove the main worktree: $target"
	fi

	info "Removing worktree: $target"
	if [ "$force" = true ]; then
		git worktree remove --force "$target" >&2 || die "Failed to remove worktree: $target"
	else
		git worktree remove "$target" >&2 ||
			die "Failed to remove worktree (pass --force to discard local changes): $target"
	fi

	success "Removed $target"
}
