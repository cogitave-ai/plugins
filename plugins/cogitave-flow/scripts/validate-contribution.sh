#!/usr/bin/env bash
#
# validate-contribution.sh — cogitave-flow Stop hook
#
# Day-0 REFERENCE IMPLEMENTATION. Runs at end-of-turn and prints a Definition of
# Done (DoD) summary for the contribution, derived from the estate's
# definition-of-done.md (the review-stage gate). It is ADVISORY: it always
# exits 0 and writes warnings to stderr so the author sees gaps before opening
# the request for review. The authoritative, queryable computation is the Core
# `get_dod` MCP tool over the Request node; this hook is the offline reminder.
#
# Contract:
#   - stdin JSON: { ... } (Stop events carry session metadata; not required here).
#   - exit 0 always (warn-only). Never blocks the Stop.
#
# DoD source resolution (first that exists wins):
#   $COGITAVE_DOD_FILE
#     -> ./agents/lifecycle/definition-of-done.md
#     -> ./cogitave/agents/lifecycle/definition-of-done.md
# If none is found, emit the built-in Core checklist so the reminder still fires.

set -euo pipefail

# Drain stdin (Stop event); we do not need its fields for the Day-0 summary.
cat >/dev/null 2>&1 || true

note() { printf '%s\n' "$*" >&2; }

# --- locate the DoD reference ------------------------------------------------
dod_file=""
for candidate in \
  "${COGITAVE_DOD_FILE:-}" \
  "./agents/lifecycle/definition-of-done.md" \
  "./cogitave/agents/lifecycle/definition-of-done.md"; do
  [ -n "$candidate" ] || continue
  if [ -f "$candidate" ]; then
    dod_file="$candidate"
    break
  fi
done

note "────────────────────────────────────────────────────────────"
note "cogitave-flow: Definition of Done — end-of-turn summary (advisory)"
note "The review stage advances 'review -> done' only at DoD == 100% +"
note "CODEOWNER approval. Confirm each item before proposing for review."
note "────────────────────────────────────────────────────────────"

# --- gather lightweight, offline signal --------------------------------------
# These are heuristics, not the real gate. They help the author self-check.
docs_changed="unknown"; code_changed="unknown"
if command -v git >/dev/null 2>&1 && git rev-parse --git-dir >/dev/null 2>&1; then
  changed="$(git status --porcelain 2>/dev/null | awk '{print $2}' || true)"
  if [ -n "$changed" ]; then
    if printf '%s\n' "$changed" | grep -Eq '\.(md|mdx|markdown)$|/docs/|CHANGELOG'; then
      docs_changed="yes"
    else
      docs_changed="no"
    fi
    if printf '%s\n' "$changed" | grep -Eq '\.(rs|go|ts|tsx|js|py|sh|sql|json|ya?ml|toml|tf)$'; then
      code_changed="yes"
    else
      code_changed="no"
    fi
  else
    docs_changed="none"; code_changed="none"
  fi
fi

# --- print the checklist -----------------------------------------------------
if [ -n "$dod_file" ]; then
  note "DoD source: ${dod_file}"
  note ""
  note "Core checklist (every Request) — verify each is PASS or recorded waiver:"
  # Pull the Core checklist table rows (lines starting with '| C').
  while IFS= read -r line; do
    item="$(printf '%s' "$line" | sed -E 's/^\| *(C[0-9]+) *\| *\*\*([^*]+)\*\*.*/  [ ] \1 — \2/' )"
    note "$item"
  done < <(grep -E '^\| C[0-9]+ \|' "$dod_file" || true)
else
  note "DoD source: built-in fallback (definition-of-done.md not found)."
  note ""
  note "Core checklist (every Request):"
  note "  [ ] C1  Code review complete; threads resolved"
  note "  [ ] C2  Tests added/updated and green"
  note "  [ ] C3  Evals green for agent-behavior changes"
  note "  [ ] C4  docs-required satisfied (docs/ | *.md | CHANGELOG)"
  note "  [ ] C5  Conventional Commits, all commits signed/Verified"
  note "  [ ] C6  English only, ASCII-clean"
  note "  [ ] C7  Least privilege honored (no broadened grant)"
  note "  [ ] C8  No unapproved mutation (no protected write/apply/release)"
  note "  [ ] C9  No secrets committed or logged"
  note "  [ ] C10 Standards honored for touched areas"
  note "  [ ] C11 Request links complete (issue, PR, RFC/ADR if design-class)"
  note "  [ ] C12 Evidence recorded (trace + completion token)"
fi

# --- flag the obvious gap ----------------------------------------------------
note ""
if [ "$code_changed" = "yes" ] && [ "$docs_changed" = "no" ]; then
  note "WARN: code changed but no docs/CHANGELOG change detected -> C4 at risk."
  note "      Update docs before review (mirrors the docs-required CI gate)."
fi
note "Conditional items (added by classification: breaking / security / perf /"
note "a11y / deps / design-class) — confirm any that apply via Core get_dod."
note ""
note "Authoritative gate: Core get_dod over the Request node. This summary is a"
note "Day-0 reminder only; it does not block. Resolve gaps, then advance_stage"
note "(propose-only) to request review."
note "────────────────────────────────────────────────────────────"

exit 0
