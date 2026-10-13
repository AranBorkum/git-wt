# shellcheck shell=bash
#
# `git wt create` — add a worktree in a directory derived from the branch name.

create_usage() {
	cat >&2 <<'EOF'
Usage: git wt create <branch-name> [base-branch]

Creates a git worktree in a directory derived from the branch name, creates
(or checks out) the branch, and runs the repository's .worktree hook.

Arguments:
  branch-name   Name of the branch to create/checkout
  base-branch   Branch to base the new branch on (default: current HEAD)

Options:
  -y, --yes     Assume yes for prompts; never read from the terminal
  -h, --help    Show this help

On success the worktree path is printed to stdout, so you can do:
  cd "$(git wt create my-feature)"
EOF
}

# Reject branch names that git would refuse, or that would escape the repo root
# once interpolated into a path.
validate_branch_name() {
	local branch="$1"

	case "$branch" in
		-* | /* | */) die "Invalid branch name: '$branch'" ;;
		*..* | *//*) die "Invalid branch name: '$branch'" ;;
	esac

	if ! git check-ref-format --branch "$branch" >/dev/null 2>&1; then
		die "Invalid branch name: '$branch'"
	fi
}

# Run the repository's .worktree hook, if it is present and executable.
#
# A failing hook is a warning rather than a fatal error: the worktree is
# already created at this point and is perfectly usable without it.
run_worktree_hook() {
	local repo_root="$1" worktree_dir="$2"
	local hook="$repo_root/.worktree"

	if [ ! -f "$hook" ]; then
		info "No .worktree script found at: $hook"
		return 0
	fi

	if [ ! -x "$hook" ]; then
		warn ".worktree script found but not executable"
		info "Run: chmod +x $hook"
		return 0
	fi

	info "Running .worktree script..."
	blank
	local status=0
	(cd "$worktree_dir" && "$hook") || status=$?
	blank
	if [ "$status" -eq 0 ]; then
		success ".worktree script completed"
	else
		warn ".worktree script failed (exit code: $status)"
	fi
}

create_worktree() {
	local assume_yes=false

	while [ $# -gt 0 ]; do
		case "$1" in
			-h | --help)
				create_usage
				return 0
				;;
			-y | --yes)
				assume_yes=true
				shift
				;;
			--)
				shift
				break
				;;
			-*)
				error "Unknown option: $1"
				create_usage
				return 2
				;;
			*)
				break
				;;
		esac
	done

	if [ $# -lt 1 ]; then
		create_usage
		return 2
	fi

	local branch="$1"
	local base="${2:-HEAD}"

	require_git_repo
	validate_branch_name "$branch"

	local repo_root worktree_dir
	repo_root=$(repo_root)
	worktree_dir="$repo_root/$branch"

	heading "🌳 Git Worktree Create"
	blank
	printf 'Branch:     %s\n' "$branch" >&2
	printf 'Base:       %s\n' "$base" >&2
	printf 'Repo root:  %s\n' "$repo_root" >&2
	blank

	[ -e "$worktree_dir" ] && die "Worktree directory already exists: $worktree_dir"

	local existing=false
	if branch_exists "$branch"; then
		existing=true
		info "Branch '$branch' already exists"
		if [ "$assume_yes" = false ]; then
			if [ ! -t 0 ]; then
				die "Branch '$branch' already exists; re-run with --yes to use it"
			fi
			local reply
			read -r -p "Use existing branch? (y/n): " reply
			[[ "$reply" =~ ^[Yy]$ ]] || die "Aborted."
		fi
		blank
	elif ! rev_exists "$base"; then
		die "Base branch does not exist: $base"
	fi

	# Branch names may contain slashes, which become nested directories.
	local parent_dir
	parent_dir=$(dirname "$worktree_dir")
	if [ ! -d "$parent_dir" ]; then
		info "Creating parent directory: $parent_dir"
		mkdir -p "$parent_dir"
	fi

	info "Creating worktree at: $worktree_dir"
	if [ "$existing" = true ]; then
		git worktree add "$worktree_dir" "$branch" >&2 || die "Failed to create worktree"
	else
		git worktree add -b "$branch" "$worktree_dir" "$base" >&2 ||
			die "Failed to create worktree with new branch"
	fi
	success "Worktree created"
	blank

	run_worktree_hook "$repo_root" "$worktree_dir"

	blank
	success "Done!"
	blank
	info "To change to this worktree, run:"
	printf '  cd %s\n' "$worktree_dir" >&2

	# Primary output: the path, so the command composes with cd.
	printf '%s\n' "$worktree_dir"
}
