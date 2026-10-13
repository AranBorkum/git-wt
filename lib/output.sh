# shellcheck shell=bash
#
# Message helpers. Everything that is not primary output goes to stderr so
# that `git wt` can be composed in a pipeline without the chatter leaking in.

info() {
	printf 'ℹ️  %s\n' "$*" >&2
}

success() {
	printf '✓ %s\n' "$*" >&2
}

warn() {
	printf '⚠️  Warning: %s\n' "$*" >&2
}

error() {
	printf '❌ Error: %s\n' "$*" >&2
}

die() {
	error "$*"
	exit 1
}

blank() {
	printf '\n' >&2
}

heading() {
	local text="$*"
	printf '%s\n' "$text" >&2
	printf '%*s\n' "${#text}" '' | tr ' ' '=' >&2
}
