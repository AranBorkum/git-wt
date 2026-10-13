#!/usr/bin/env bash
#
# Top-level CLI behaviour: dispatch, help, version, unknown commands.

set -euo pipefail
# shellcheck source=tests/helper.sh
source "$(dirname "${BASH_SOURCE[0]}")/helper.sh"

test_version_prints_version() {
	run_wt version
	assert_success "$status"
	assert_contains "$output" "git-wt"
}

test_version_flag_matches_subcommand() {
	run_wt --version
	local via_flag="$output"
	run_wt version
	assert_equal "$output" "$via_flag" "--version and version agree"
}

test_version_matches_lib_file() {
	# The release workflow parses lib/version.sh, so the two must not drift.
	local parsed
	parsed=$(sed -n 's/^readonly GIT_WT_VERSION="\(.*\)"$/\1/p' "$REPO_DIR/lib/version.sh")
	run_wt version
	assert_equal "git-wt $parsed" "$output" "reported version"
}

test_no_args_shows_usage() {
	run_wt
	assert_contains "$stderr" "Usage: git wt"
}

test_help_shows_all_commands() {
	run_wt help
	assert_contains "$stderr" "create"
	assert_contains "$stderr" "delete"
	assert_contains "$stderr" "list"
}

test_unknown_command_fails_with_code_2() {
	run_wt bogus-command
	assert_equal "2" "$status" "exit code"
	assert_contains "$stderr" "unknown command"
}

test_create_without_branch_fails() {
	# Regression: main() used to forward the command name as the branch, so
	# `git wt create` silently made a worktree called "create".
	run_wt create
	assert_equal "2" "$status" "exit code"
	assert_dir_missing "$(dirname "$PWD")/create"
}

test_outside_git_repo_fails() {
	cd "$TEST_TMP"
	run_wt list
	assert_failure "$status"
	assert_contains "$stderr" "Not in a git repository"
}

run_tests
