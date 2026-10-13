#!/usr/bin/env bash
#
# `git wt delete` and `git wt list` behaviour.

set -euo pipefail
# shellcheck source=tests/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/helper.sh"

test_deletes_by_branch_name() {
	run_wt create doomed
	run_wt delete doomed
	assert_success "$status"
	assert_dir_missing "$WT_ROOT/doomed"
}

test_deletes_by_path() {
	run_wt create doomed
	run_wt delete "$WT_ROOT/doomed"
	assert_success "$status"
	assert_dir_missing "$WT_ROOT/doomed"
}

test_unknown_target_fails() {
	run_wt delete no-such-worktree
	assert_failure "$status"
	assert_contains "$stderr" "No worktree matching"
}

test_refuses_to_delete_main_worktree() {
	run_wt delete "$TEST_TMP/repo"
	assert_failure "$status"
	assert_dir_exists "$TEST_TMP/repo"
}

test_dirty_worktree_needs_force() {
	run_wt create dirty
	printf 'uncommitted\n' >"$WT_ROOT/dirty/scratch.txt"
	git -C "$WT_ROOT/dirty" add scratch.txt

	run_wt delete dirty
	assert_failure "$status"
	assert_contains "$stderr" "--force"
	assert_dir_exists "$WT_ROOT/dirty"

	run_wt delete --force dirty
	assert_success "$status"
	assert_dir_missing "$WT_ROOT/dirty"
}

test_list_shows_main_and_created_worktrees() {
	run_wt create listed
	run_wt list
	assert_success "$status"
	assert_contains "$output" "$TEST_TMP/repo"
	assert_contains "$output" "$WT_ROOT/listed"
	assert_contains "$output" "listed"
}

test_list_paths_is_bare_paths() {
	run_wt create listed
	run_wt list --paths
	assert_success "$status"
	assert_equal "2" "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" "line count"
	assert_not_contains "$output" "main"
}

test_list_reports_detached_head() {
	run_wt create detachme
	git -C "$WT_ROOT/detachme" checkout --quiet --detach HEAD
	run_wt list
	assert_contains "$output" "(detached)"
}

run_tests
