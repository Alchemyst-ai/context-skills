#!/bin/bash
set -e

echo "=== AlchemystAI Skills Setup ===" >&2
echo "Installing agent skills..." >&2

# Check Node.js is available
if ! command -v node &> /dev/null; then
  echo "ERROR: Node.js is required. Install it first: https://nodejs.org" >&2
  exit 1
fi

# Check npx is available
if ! command -v npx &> /dev/null; then
  echo "ERROR: npx not found. Comes with npm 5.2+. Run: npm install -g npm" >&2
  exit 1
fi

echo "" >&2
echo "[1/2] Installing all Vercel agent-skills..." >&2
npx skills add vercel-labs/agent-skills --all -y

echo "" >&2
echo "[2/2] Installing skill-creator from anthropics/skills..." >&2
npx skills add anthropics/skills --skill skill-creator -y

echo "" >&2
echo "=== Done ===" >&2
echo "Installed skills:" >&2
npx skills list 2>/dev/null || echo "(Run 'npx skills list' to verify)" >&2