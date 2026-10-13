#!/usr/bin/env bash
#
# `git wt create` behaviour.

set -euo pipefail
# shellcheck source=tests/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/helper.sh"

test_creates_worktree_and_branch() {
	run_wt create feature-a
	assert_success "$status"
	assert_dir_exists "$WT_ROOT/feature-a"
	assert_equal "$WT_ROOT/feature-a" "$output" "printed path"
	# The branch should exist and be checked out in the new worktree.
	assert_equal "feature-a" "$(git -C "$WT_ROOT/feature-a" branch --show-current)"
}

test_stdout_is_only_the_path() {
	# `cd "$(git wt create x)"` must work, so stdout carries nothing else.
	run_wt create feature-b
	assert_equal "1" "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" "stdout line count"
	assert_not_contains "$output" "🌳"
	assert_not_contains "$output" "Done"
}

test_nested_branch_name_creates_directories() {
	run_wt create feat/nested/thing
	assert_success "$status"
	assert_dir_exists "$WT_ROOT/feat/nested/thing"
}

test_base_branch_is_respected() {
	git checkout --quiet -b other
	printf 'other\n' >other.txt
	git add other.txt
	git commit --quiet -m "other commit"
	git checkout --quiet main

	run_wt create from-other other
	assert_success "$status"
	# The file from `other` should be present, proving the base was used.
	[ -f "$WT_ROOT/from-other/other.txt" ] || fail "expected other.txt in new worktree"
}

test_existing_directory_is_refused() {
	mkdir -p "$WT_ROOT/taken"
	run_wt create taken
	assert_failure "$status"
	assert_contains "$stderr" "already exists"
}

test_missing_base_branch_is_refused() {
	run_wt create newbranch no-such-base
	assert_failure "$status"
	assert_contains "$stderr" "Base branch does not exist"
	assert_dir_missing "$WT_ROOT/newbranch"
}

test_existing_branch_needs_yes_when_not_a_tty() {
	git branch existing
	run_wt create existing
	assert_failure "$status"
	assert_contains "$stderr" "re-run with --yes"
}

test_existing_branch_with_yes_checks_it_out() {
	git branch existing
	run_wt create --yes existing
	assert_success "$status"
	assert_dir_exists "$WT_ROOT/existing"
	assert_equal "existing" "$(git -C "$WT_ROOT/existing" branch --show-current)"
}

test_invalid_branch_names_are_refused() {
	local bad
	for bad in "with space" "has..dots" "trailing/" "bad~char"; do
		run_wt create "$bad"
		assert_failure "$status" "branch '$bad'"
		assert_contains "$stderr" "Invalid branch name" "branch '$bad'"
	done
}

test_path_traversal_branch_name_is_refused() {
	run_wt create ../escaped
	assert_failure "$status"
	assert_dir_missing "$WT_ROOT/../escaped"
}

test_worktree_hook_runs_in_new_worktree() {
	cat >"$TEST_TMP/repo/.worktree" <<'EOF'
#!/usr/bin/env bash
printf 'hook ran in %s\n' "$PWD" > hook-output.txt
EOF
	chmod +x "$TEST_TMP/repo/.worktree"

	run_wt create hooked
	assert_success "$status"
	# The hook is stored at the repo root but must execute inside the worktree.
	[ -f "$WT_ROOT/hooked/hook-output.txt" ] ||
		fail "expected hook to run with the worktree as cwd"
	assert_contains "$(cat "$WT_ROOT/hooked/hook-output.txt")" "$WT_ROOT/hooked"
}

test_non_executable_hook_warns_but_succeeds() {
	printf '#!/usr/bin/env bash\ntrue\n' >"$TEST_TMP/repo/.worktree"
	chmod -x "$TEST_TMP/repo/.worktree"

	run_wt create unhooked
	assert_success "$status"
	assert_contains "$stderr" "not executable"
	assert_dir_exists "$WT_ROOT/unhooked"
}

test_failing_hook_warns_but_worktree_survives() {
	printf '#!/usr/bin/env bash\nexit 3\n' >"$TEST_TMP/repo/.worktree"
	chmod +x "$TEST_TMP/repo/.worktree"

	run_wt create brokenhook
	assert_success "$status" "create should still succeed"
	assert_contains "$stderr" "exit code: 3"
	assert_dir_exists "$WT_ROOT/brokenhook"
}

test_help_does_not_create_anything() {
	run_wt create --help
	assert_success "$status"
	assert_contains "$stderr" "Usage: git wt create"
	assert_dir_missing "$WT_ROOT/--help"
}

run_tests
