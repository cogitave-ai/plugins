#!/usr/bin/env bash
#
# docs-gate.sh — cogitave-flow PostToolUse hook (matcher: Write|Edit)
#
# Day-0 REFERENCE IMPLEMENTATION. Enforces the org docs-as-code floor locally:
# "If code changes, docs change." (root AGENTS.md §4 / the `docs-required` CI
# gate). The CI gate remains the canonical enforcement; this hook gives the
# author the same signal at edit time so the PR does not fail later.
#
# Contract (Claude Code hooks):
#   - Reads a JSON event object on stdin: { tool_name, tool_input, ... }.
#     For Write/Edit the changed file is tool_input.file_path.
#   - exit 0  -> allow / no objection.
#   - exit 2  -> block, with a human-readable reason on stderr.
#
# Behavior: tracks every file touched this session in a ledger. When a CODE/
# SCHEMA file is written and the session has NO matching docs change yet
# (docs/, any *.md, or CHANGELOG), it blocks with guidance. Writing a doc file
# clears the condition. This is intentionally simple and offline — no network.

set -euo pipefail

# --- read the hook event -----------------------------------------------------
payload="$(cat || true)"

# jq is the documented way to parse hook stdin. Degrade safely if absent.
if ! command -v jq >/dev/null 2>&1; then
  echo "docs-gate: jq not found; skipping docs-as-code check (advisory only)." >&2
  exit 0
fi

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty')"

# Only Write/Edit carry a file_path; nothing to do otherwise.
[ -n "$file_path" ] || exit 0
case "$tool_name" in
  Write | Edit | MultiEdit | NotebookEdit) : ;;
  *) exit 0 ;;
esac

# --- session ledger ----------------------------------------------------------
# One ledger per session so the check reasons over the whole turn, not one file.
session_id="${CLAUDE_SESSION_ID:-default}"
state_dir="${TMPDIR:-/tmp}/cogitave-flow-docs-gate"
ledger="${state_dir}/${session_id}.ledger"
mkdir -p "$state_dir"
printf '%s\n' "$file_path" >>"$ledger"

# --- classification ----------------------------------------------------------
# A path is a "doc change" if it is a markdown file, lives under a docs/ tree,
# or is a CHANGELOG. Everything else that looks like source/schema is "code".
is_doc() {
  case "$1" in
    *.md | *.mdx | *.markdown) return 0 ;;
    */docs/* | docs/*) return 0 ;;
    *CHANGELOG* | *changelog*) return 0 ;;
    *) return 1 ;;
  esac
}

is_code() {
  # Treat common source + schema + config-as-code extensions as "code".
  case "$1" in
    *.rs | *.go | *.ts | *.tsx | *.js | *.jsx | *.py | *.sh | *.sql) return 0 ;;
    *.json | *.yaml | *.yml | *.toml | *.tf | *.proto | *.graphql) return 0 ;;
    *) return 1 ;;
  esac
}

# If THIS write is a doc change, the session is satisfied — allow.
if is_doc "$file_path"; then
  exit 0
fi

# Non-code, non-doc files (e.g. images, lockfiles) are out of scope.
is_code "$file_path" || exit 0

# Does the ledger already contain any doc change this session?
doc_seen=0
while IFS= read -r touched; do
  [ -n "$touched" ] || continue
  if is_doc "$touched"; then
    doc_seen=1
    break
  fi
done <"$ledger"

if [ "$doc_seen" -eq 1 ]; then
  exit 0
fi

# --- block: code changed, no docs yet ---------------------------------------
cat >&2 <<EOF
docs-gate: BLOCKED — code/schema changed without a documentation change.

  changed: ${file_path}

Cogitave is docs-as-code (AGENTS.md §4): a change that touches code must also
update docs. Add or update one of the following in this session, then retry:
  - a docs/ page (DocFX front matter: uid/title/type/owner/lastReviewed/status)
  - a *.md explanation/reference/how-to
  - a CHANGELOG entry (required for user-visible or breaking changes)

This mirrors the 'docs-required' CI gate (DoD item C4) so the PR will not fail
review later. If the change is genuinely doc-exempt, record the rationale in the
PR and have a human waive it — do not bypass the gate silently.
EOF
exit 2
