#!/usr/bin/env bash
#
# Run every test file and summarise. Exits non-zero if any file fails.

set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")" || exit 1

failed=0
files=()
for file in test_*.sh; do
	files+=("$file")
done

if [ "${#files[@]}" -eq 0 ]; then
	printf 'No test files found.\n' >&2
	exit 1
fi

for file in "${files[@]}"; do
	printf '\n==> %s\n' "$file" >&2
	bash "$file" || failed=$((failed + 1))
done

printf '\n'
if [ "$failed" -ne 0 ]; then
	printf '❌ %d test file(s) failed\n' "$failed" >&2
	exit 1
fi

printf '✅ All test files passed\n' >&2
