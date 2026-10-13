# shellcheck shell=bash
#
# A tiny test harness. No dependencies beyond bash and git, so `make test`
# works on a clean machine and in CI without installing anything.
#
# Each test file sources this, defines `test_*` functions, and calls
# `run_tests` at the end.

TESTS_RUN=0
TESTS_FAILED=0
FAILED_NAMES=()

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GIT_WT="$REPO_DIR/git-wt"
export REPO_DIR GIT_WT

# --- assertions -------------------------------------------------------------

fail() {
	printf '    %s\n' "$*" >&2
	CURRENT_TEST_FAILED=1
}

assert_equal() {
	local expected="$1" actual="$2" label="${3:-}"
	if [ "$expected" != "$actual" ]; then
		fail "${label:+$label: }expected '$expected', got '$actual'"
	fi
}

assert_contains() {
	local haystack="$1" needle="$2" label="${3:-}"
	case "$haystack" in
		*"$needle"*) ;;
		*) fail "${label:+$label: }expected output to contain '$needle', got '$haystack'" ;;
	esac
}

assert_not_contains() {
	local haystack="$1" needle="$2" label="${3:-}"
	case "$haystack" in
		*"$needle"*) fail "${label:+$label: }expected output NOT to contain '$needle'" ;;
	esac
}

assert_success() {
	local status="$1" label="${2:-}"
	[ "$status" -eq 0 ] || fail "${label:+$label: }expected success, got exit $status"
}

assert_failure() {
	local status="$1" label="${2:-}"
	[ "$status" -ne 0 ] || fail "${label:+$label: }expected failure, got exit 0"
}

assert_dir_exists() {
	[ -d "$1" ] || fail "${2:+$2: }expected directory to exist: $1"
}

assert_dir_missing() {
	[ ! -d "$1" ] || fail "${2:+$2: }expected directory NOT to exist: $1"
}

# --- fixtures ---------------------------------------------------------------

# Create a scratch git repository with one commit and cd into it. The
# containing temp dir is recorded so teardown can remove it.
setup_repo() {
	TEST_TMP=$(mktemp -d "${TMPDIR:-/tmp}/git-wt-test.XXXXXX")
	# macOS mktemp returns /var/... which is a symlink to /private/var; resolve
	# it so path comparisons against git's output match.
	TEST_TMP=$(cd "$TEST_TMP" && pwd -P)
	mkdir -p "$TEST_TMP/repo"
	cd "$TEST_TMP/repo"

	# git-wt creates worktrees beside the repository's git dir, which for a
	# normal checkout is the working tree itself.
	# shellcheck disable=SC2034  # read by the test files that source this
	WT_ROOT="$TEST_TMP/repo"

	git init --quiet --initial-branch=main .
	git config user.name "Test User"
	git config user.email "test@example.com"
	git config commit.gpgsign false
	printf 'hello\n' >README.md
	git add README.md
	git commit --quiet -m "initial commit"
}

teardown_repo() {
	cd /
	[ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ] && rm -rf "$TEST_TMP"
	TEST_TMP=""
}

# Run `git wt` capturing stdout only; stderr is kept separately in
# $STDERR_FILE so tests can assert on messages without mixing streams.
#
# shellcheck disable=SC2034  # output/status/stderr are read by the test files
run_wt() {
	STDERR_FILE="${TEST_TMP:-${TMPDIR:-/tmp}}/stderr.$$"
	set +e
	output=$("$GIT_WT" "$@" 2>"$STDERR_FILE")
	status=$?
	set -e
	stderr=$(cat "$STDERR_FILE")
	rm -f "$STDERR_FILE"
}

# --- runner -----------------------------------------------------------------

run_tests() {
	local name
	# Deliberately iterate in declaration order via the caller's list.
	for name in $(declare -F | awk '{print $3}' | grep '^test_'); do
		TESTS_RUN=$((TESTS_RUN + 1))
		CURRENT_TEST_FAILED=0

		setup_repo
		"$name" || CURRENT_TEST_FAILED=1
		teardown_repo

		if [ "$CURRENT_TEST_FAILED" -ne 0 ]; then
			TESTS_FAILED=$((TESTS_FAILED + 1))
			FAILED_NAMES+=("$name")
			printf '  ✗ %s\n' "$name" >&2
		else
			printf '  ✓ %s\n' "$name" >&2
		fi
	done

	printf '\n%s: %d run, %d failed\n' \
		"$(basename "${BASH_SOURCE[1]}")" "$TESTS_RUN" "$TESTS_FAILED" >&2

	if [ "$TESTS_FAILED" -ne 0 ]; then
		printf 'Failed: %s\n' "${FAILED_NAMES[*]}" >&2
		exit 1
	fi
}
