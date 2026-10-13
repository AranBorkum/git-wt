# shellcheck shell=bash
#
# `git wt list` — show the repository's worktrees.

list_usage() {
	cat >&2 <<'EOF'
Usage: git wt list [--paths]

Lists the repository's worktrees and the branch each has checked out.

Options:
      --paths   Print bare paths only, one per line (for scripting)
  -h, --help    Show this help
EOF
}

list_worktrees() {
	local paths_only=false

	while [ $# -gt 0 ]; do
		case "$1" in
			-h | --help)
				list_usage
				return 0
				;;
			--paths)
				paths_only=true
				shift
				;;
			-*)
				error "Unknown option: $1"
				list_usage
				return 2
				;;
			*)
				error "Unexpected argument: $1"
				list_usage
				return 2
				;;
		esac
	done

	require_git_repo

	if [ "$paths_only" = true ]; then
		worktree_paths
		return 0
	fi

	# Walk the porcelain output into "path<TAB>branch" records. A record is
	# complete when the next "worktree " line starts, or at end of input.
	local records="" path="" branch="" line
	while IFS= read -r line; do
		case "$line" in
			worktree\ *)
				if [ -n "$path" ]; then
					records+="$path	${branch:-(detached)}"$'\n'
				fi
				path="${line#worktree }"
				branch=""
				;;
			branch\ refs/heads/*)
				branch="${line#branch refs/heads/}"
				;;
			detached) branch="(detached)" ;;
		esac
	done < <(git worktree list --porcelain)
	if [ -n "$path" ]; then
		records+="$path	${branch:-(detached)}"$'\n'
	fi

	[ -n "$records" ] || return 0

	# Pad the path column so the branch names line up.
	local width=0 candidate
	while IFS=$'\t' read -r candidate _; do
		[ "${#candidate}" -gt "$width" ] && width=${#candidate}
	done <<<"$records"

	while IFS=$'\t' read -r path branch; do
		[ -n "$path" ] || continue
		printf '%-*s  %s\n' "$width" "$path" "$branch"
	done <<<"$records"
}
