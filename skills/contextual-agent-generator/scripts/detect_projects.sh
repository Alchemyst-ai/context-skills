#!/usr/bin/env bash
# detect_projects.sh — Discover project roots (flat or nested) in a repo.
# Usage: bash detect_projects.sh <TARGET_DIR>
#
# Emits one TSV line per project:
#   <abs_path>\t<slug_chain>\t<language_hint>\t<framework_hint>
# where slug_chain is the joined parent slugs + own slug with "--" separators,
# matching the generated skill suffix used after "k6-testing--".
#
# Heuristics (in order):
#   1. workspace manifests that declare member globs -> enumerate members
#   2. presence of a "project manifest" file (package.json, pyproject.toml,
#      go.mod, Cargo.toml, pom.xml, build.gradle*, Gemfile, composer.json,
#      mix.exs, requirements.txt) -> that directory is a project root
#   3. nested project roots are emitted with --joined slug chains
#   4. if no manifests are found anywhere, fall back to TARGET_DIR itself

set -euo pipefail

TARGET_DIR="${1:-.}"
if [[ ! -d "$TARGET_DIR" ]]; then
  echo "ERROR: '$TARGET_DIR' is not a directory" >&2
  exit 1
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SLUGIFY="$SCRIPT_DIR/slugify.sh"

# --- helpers ---------------------------------------------------------------

slug() { bash "$SLUGIFY" "$1"; }

# Build a "--"-joined slug chain for a project directory.
# - If the project dir IS the target (single-repo case), use basename(target).
# - Otherwise the target is treated as a wrapper/monorepo root that is NOT
#   part of the chain; segments come from the relative path target->project.
chain_for() {
  local abs="$1"
  local rel="${abs#"$TARGET_DIR"}"
  rel="${rel#/}"
  if [[ -z "$rel" ]]; then
    slug "$(basename "$TARGET_DIR")"
    return
  fi
  local parts=()
  IFS='/' read -r -a segs <<< "$rel"
  local s
  for s in "${segs[@]}"; do
    [[ -z "$s" ]] && continue
    parts+=("$(slug "$s")")
  done
  local out="${parts[0]}"
  local i
  for ((i=1; i<${#parts[@]}; i++)); do
    out="${out}--${parts[$i]}"
  done
  printf '%s' "$out"
}

# Identify language/framework from the manifests present in a dir.
classify() {
  local d="$1"
  local lang="" fw=""
  if [[ -f "$d/package.json" ]]; then
    lang="javascript"
    if grep -qE '"(next|@next/[a-z]+)"' "$d/package.json" 2>/dev/null; then fw="next"
    elif grep -qE '"@nestjs/' "$d/package.json" 2>/dev/null; then fw="nestjs"
    elif grep -qE '"fastify"' "$d/package.json" 2>/dev/null; then fw="fastify"
    elif grep -qE '"express"' "$d/package.json" 2>/dev/null; then fw="express"
    elif grep -qE '"hono"' "$d/package.json" 2>/dev/null; then fw="hono"
    elif grep -qE '"@trpc/' "$d/package.json" 2>/dev/null; then fw="trpc"
    fi
  fi
  if [[ -f "$d/pyproject.toml" || -f "$d/requirements.txt" ]]; then
    lang="python"
    if grep -qEi 'fastapi' "$d/pyproject.toml" "$d/requirements.txt" 2>/dev/null; then fw="fastapi"
    elif grep -qEi 'flask' "$d/pyproject.toml" "$d/requirements.txt" 2>/dev/null; then fw="flask"
    elif grep -qEi 'django' "$d/pyproject.toml" "$d/requirements.txt" 2>/dev/null; then fw="django"
    fi
  fi
  [[ -f "$d/go.mod" ]] && lang="go"
  [[ -f "$d/Cargo.toml" ]] && lang="rust"
  [[ -f "$d/pom.xml" || -f "$d/build.gradle" || -f "$d/build.gradle.kts" ]] && lang="jvm"
  [[ -f "$d/Gemfile" ]] && lang="ruby"
  [[ -f "$d/composer.json" ]] && lang="php"
  [[ -f "$d/mix.exs" ]] && lang="elixir"
  printf '%s\t%s' "${lang:-unknown}" "${fw:-generic}"
}

# --- discovery -------------------------------------------------------------

# Find every directory that looks like a project root. Exclude vendored dirs.
roots_file="$(mktemp)"
trap 'rm -f "$roots_file"' EXIT

find "$TARGET_DIR" \
  \( -name node_modules -o -name .venv -o -name venv -o -name vendor \
     -o -name dist -o -name build -o -name target -o -name .git \
     -o -name __pycache__ -o -name .next -o -name .nuxt \
     -o -name .terraform -o -name .agents -o -name .claude \) -prune -o \
  -type f \( \
    -name package.json -o -name pyproject.toml -o -name requirements.txt \
    -o -name go.mod -o -name Cargo.toml -o -name pom.xml \
    -o -name build.gradle -o -name build.gradle.kts \
    -o -name Gemfile -o -name composer.json -o -name mix.exs \
  \) -print 2>/dev/null | while read -r m; do
    dirname "$m"
  done | sort -u > "$roots_file"

# If no manifest found, emit the target directory itself.
if [[ ! -s "$roots_file" ]]; then
  class="$(classify "$TARGET_DIR")"
  printf '%s\t%s\t%s\n' "$TARGET_DIR" "$(slug "$(basename "$TARGET_DIR")")" "$class"
  exit 0
fi

# Emit sorted by path so parents come before children.
while read -r d; do
  cls="$(classify "$d")"
  chain="$(chain_for "$d")"
  printf '%s\t%s\t%s\n' "$d" "$chain" "$cls"
done < "$roots_file"
