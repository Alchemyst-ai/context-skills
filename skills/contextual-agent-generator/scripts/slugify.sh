#!/usr/bin/env bash
# slugify.sh — Turn a free-form name into a k6-testing skill slug component.
# Usage: bash slugify.sh "Project 1"   ->  project-1
#        echo "My_Repo.v2" | bash slugify.sh
#
# Rules: lowercase, spaces/underscores/dots -> hyphens, strip non-[a-z0-9-],
# collapse repeated hyphens, trim leading/trailing hyphens.

set -euo pipefail

input="${1:-}"
if [[ -z "$input" ]]; then
  input="$(cat)"
fi

printf '%s' "$input" \
  | tr '[:upper:]' '[:lower:]' \
  | tr ' _.' '-' \
  | sed 's/[^a-z0-9-]//g; s/--*/-/g; s/^-//; s/-$//'
