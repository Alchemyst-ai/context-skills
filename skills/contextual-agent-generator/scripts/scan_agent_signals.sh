#!/usr/bin/env bash
# scan_agent_signals.sh — Surface signals about an existing project that
# inform an Alchemyst retrofit plan: where the LLM call lives, where
# the system prompt lives, language/framework, and any pre-existing
# context layer.
#
# Usage: bash scan_agent_signals.sh <PROJECT_DIR>
#
# Output: a TSV of one signal per line:
#   <signal_kind>\t<file_path>\t<line_no_or_blank>\t<extra>
# Signal kinds:
#   llm_call_site
#   system_prompt_file
#   system_prompt_string
#   language_signal
#   framework_signal
#   existing_context_layer
#   tenant_boundary
#   secret_pattern

set -euo pipefail

PROJECT_DIR="${1:-.}"
if [[ ! -d "$PROJECT_DIR" ]]; then
  echo "ERROR: '$PROJECT_DIR' is not a directory" >&2
  exit 1
fi
PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"

emit() {
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "${3:-}" "${4:-}"
}

# --- exclusions ------------------------------------------------------------
# Skip vendor / lock / build dirs and never read secret files.
EXCLUDES=(
  --exclude-dir=node_modules
  --exclude-dir=.git
  --exclude-dir=dist
  --exclude-dir=build
  --exclude-dir=.next
  --exclude-dir=.venv
  --exclude-dir=venv
  --exclude-dir=__pycache__
  --exclude-dir=target
  --exclude-dir=vendor
  --exclude=*.lock
  --exclude=package-lock.json
  --exclude=yarn.lock
  --exclude=pnpm-lock.yaml
  --exclude=Cargo.lock
  --exclude=poetry.lock
  --exclude=.env
  --exclude=.env.*
  --exclude=*.key
  --exclude=*.pem
  --exclude=credentials.*
)
# Allow .env.example / .env.sample / .env.template through:
ENV_SAMPLE_RE='\.env\.(example|sample|template)$'

# --- 1. language & framework signals --------------------------------------
[[ -f "$PROJECT_DIR/tsconfig.json" ]] && emit language_signal "$PROJECT_DIR/tsconfig.json" "" "typescript"
[[ -f "$PROJECT_DIR/package.json" ]] && emit language_signal "$PROJECT_DIR/package.json" "" "javascript"
[[ -f "$PROJECT_DIR/pyproject.toml" ]] && emit language_signal "$PROJECT_DIR/pyproject.toml" "" "python"
[[ -f "$PROJECT_DIR/requirements.txt" ]] && emit language_signal "$PROJECT_DIR/requirements.txt" "" "python"
[[ -f "$PROJECT_DIR/go.mod" ]] && emit language_signal "$PROJECT_DIR/go.mod" "" "go"
[[ -f "$PROJECT_DIR/Cargo.toml" ]] && emit language_signal "$PROJECT_DIR/Cargo.toml" "" "rust"

if [[ -f "$PROJECT_DIR/package.json" ]]; then
  for fw in next nestjs fastify express hono "@trpc/server" remix; do
    grep -qE "\"${fw}\"" "$PROJECT_DIR/package.json" 2>/dev/null \
      && emit framework_signal "$PROJECT_DIR/package.json" "" "$fw"
  done
fi
if [[ -f "$PROJECT_DIR/pyproject.toml" || -f "$PROJECT_DIR/requirements.txt" ]]; then
  for fw in fastapi flask django; do
    grep -qiE "(^|[[:space:]\"=,])${fw}([[:space:]\"=,>=<]|$)" \
      "$PROJECT_DIR/pyproject.toml" "$PROJECT_DIR/requirements.txt" 2>/dev/null \
      && emit framework_signal "$PROJECT_DIR" "" "$fw"
  done
fi

# --- 2. LLM call sites ----------------------------------------------------
# Patterns that almost-always indicate an LLM call insertion point.
LLM_PATTERNS=(
  'messages\.create\('
  'client\.messages\.create\('
  'Anthropic\('
  'chat\.completions\.create\('
  'client\.chat\.completions\.create\('
  'responses\.create\('
  'OpenAI\('
  'generateText\('
  'streamText\('
  'generateObject\('
)
for pat in "${LLM_PATTERNS[@]}"; do
  grep -RInE "$pat" "${EXCLUDES[@]}" "$PROJECT_DIR" 2>/dev/null \
    | while IFS=: read -r f l _; do
        emit llm_call_site "$f" "$l" "$pat"
      done || true
done

# --- 3. system-prompt files -----------------------------------------------
PROMPT_NAMES=(
  '*.prompt' '*.prompt.md'
  'system_prompt.*' 'instructions.*' 'persona.*'
  'CLAUDE.md' 'AGENTS.md' '.cursorrules' '.windsurfrules'
)
for pat in "${PROMPT_NAMES[@]}"; do
  while IFS= read -r -d '' f; do
    emit system_prompt_file "$f" "" "name-match"
  done < <(find "$PROJECT_DIR" -type f -name "$pat" \
    -not -path '*/node_modules/*' -not -path '*/.git/*' \
    -not -path '*/dist/*' -not -path '*/.venv/*' -print0 2>/dev/null)
done

# Also: anything under prompts/ or agents/ directories
while IFS= read -r -d '' f; do
  emit system_prompt_file "$f" "" "prompts-dir"
done < <(find "$PROJECT_DIR" -type f \( -name '*.md' -o -name '*.txt' -o -name '*.yaml' -o -name '*.yml' \) \
  \( -path '*/prompts/*' -o -path '*/agents/*' \) \
  -not -path '*/node_modules/*' -not -path '*/.git/*' -print0 2>/dev/null)

# --- 4. system-prompt string literals -------------------------------------
SP_VAR_PATTERNS=(
  'SYSTEM_PROMPT[[:space:]]*='
  'system_prompt[[:space:]]*='
  'systemPrompt[[:space:]]*='
  'INSTRUCTIONS[[:space:]]*='
  'instructions[[:space:]]*='
)
for pat in "${SP_VAR_PATTERNS[@]}"; do
  grep -RInE "$pat" "${EXCLUDES[@]}" "$PROJECT_DIR" 2>/dev/null \
    | while IFS=: read -r f l _; do
        emit system_prompt_string "$f" "$l" "$pat"
      done || true
done

# --- 5. existing context-layer / memory libs ------------------------------
EXISTING_CTX=(
  '@alchemyst-ai/sdk'        # already integrated
  'from alchemyst'            # already integrated
  'pinecone-client' 'pinecone' '@pinecone-database'
  'weaviate-client' 'weaviate-ts-client' 'weaviate'
  'chromadb' 'chroma-js'
  'qdrant-client' '@qdrant/js-client-rest'
  'pgvector'
  'mem0ai' 'mem0'
  'getzep' 'zep-python'
)
for lib in "${EXISTING_CTX[@]}"; do
  grep -RInE "[\"'\`]${lib}[\"'\`]|from[[:space:]]+${lib}|import[[:space:]]+${lib}" \
    "${EXCLUDES[@]}" "$PROJECT_DIR" 2>/dev/null \
    | head -5 | while IFS=: read -r f l _; do
        emit existing_context_layer "$f" "$l" "$lib"
      done || true
done

# --- 6. tenant / user boundary signals ------------------------------------
BOUNDARY_PATTERNS=(
  '\borgId\b' '\borg_id\b' '\borganizationId\b'
  '\btenantId\b' '\btenant_id\b'
  '\buserId\b' '\buser_id\b'
  '\bsessionId\b' '\bsession_id\b'
)
for pat in "${BOUNDARY_PATTERNS[@]}"; do
  grep -RInE "$pat" "${EXCLUDES[@]}" "$PROJECT_DIR" 2>/dev/null \
    | head -5 | while IFS=: read -r f l _; do
        emit tenant_boundary "$f" "$l" "$pat"
      done || true
done

# --- 7. secret-pattern locations (where keys ARE stored, not the values) -
# Only emit the *pathway*, never the value.
for f in \
  "$PROJECT_DIR/.env.example" "$PROJECT_DIR/.env.sample" "$PROJECT_DIR/.env.template" \
  "$PROJECT_DIR/secrets.example.yaml" "$PROJECT_DIR/secrets.example.json"; do
  [[ -f "$f" ]] && emit secret_pattern "$f" "" "env-example"
done
# AWS Secrets Manager / Vault references in code:
grep -RInE 'SecretsManager|getSecret\(|HashiCorp Vault|vault\.read\(' \
  "${EXCLUDES[@]}" "$PROJECT_DIR" 2>/dev/null \
  | head -5 | while IFS=: read -r f l _; do
      emit secret_pattern "$f" "$l" "secrets-service"
    done || true

exit 0
