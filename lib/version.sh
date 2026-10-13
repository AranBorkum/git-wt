# shellcheck shell=bash
#
# Single source of truth for the project version.
# The release workflow parses this file, so keep the assignment on one line.

# shellcheck disable=SC2034  # consumed by the sourcing entrypoint
readonly GIT_WT_VERSION="0.1.1"
