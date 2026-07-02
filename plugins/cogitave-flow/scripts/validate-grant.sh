#!/usr/bin/env bash
#
# validate-grant.sh — cogitave-flow PreToolUse hook (matcher: Write|Edit|Bash)
#
# Day-0 REFERENCE IMPLEMENTATION. Enforces least privilege at the edge: a write
# or command may only proceed if the target path/action falls inside the acting
# agent's declared CapabilityGrant (root AGENTS.md §5 "least privilege" and §6
# "no unapproved mutation"). The unforgeable runtime token + macaroon-style
# attenuation are owned by yuva at runtime; this hook is the local, offline
# author-time mirror so an out-of-grant action is caught before it happens.
#
# Grant shape: a CapabilityGrant document validating against
#   agents/identity/capability-schema.json  (kind: CapabilityGrant)
# with capabilities[].resource.{type,ref} and capabilities[].permissions[].
#
# Contract:
#   - stdin JSON: { tool_name, tool_input, ... }.
#       Write/Edit -> tool_input.file_path ; Bash -> tool_input.command
#   - exit 0 -> allow ; exit 2 -> block with reason on stderr.
#
# Resolution of the grant file (first that exists wins):
#   $COGITAVE_GRANT_FILE  ->  ./.cogitave/grant.json  ->  ./agents/identity/grant.json
# If no grant is present (Day 0: grants are issued per-run at runtime), this hook
# is ADVISORY: it warns on stderr and exits 0, except for hard "never" actions
# (protected mutation) which are always blocked.

set -euo pipefail

payload="$(cat || true)"

if ! command -v jq >/dev/null 2>&1; then
  echo "validate-grant: jq not found; skipping grant check (advisory only)." >&2
  exit 0
fi

tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // empty')"
file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // .tool_input.path // empty')"
command_str="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty')"

# --- 1. Hard "never" rules (apply with or without a grant) -------------------
# These are NOT agent verbs at Day 0 (capability-schema: merge/release/apply/
# secret-access are excluded). Block obvious unapproved-mutation commands.
if [ -n "$command_str" ]; then
  if printf '%s' "$command_str" | grep -Eiq \
    '(terraform[[:space:]]+apply|terraform[[:space:]]+destroy|git[[:space:]]+push[^|;&]*(--force|-f)|gh[[:space:]]+release[[:space:]]+create|gh[[:space:]]+pr[[:space:]]+merge|npm[[:space:]]+publish|cargo[[:space:]]+publish|git[[:space:]]+push[^|;&]*(main|master|protected))'; then
    cat >&2 <<EOF
validate-grant: BLOCKED — unapproved mutation of the world (AGENTS.md §6).

  command: ${command_str}

apply/destroy/force-push/publish/merge/release are not agent verbs at Day 0
(capability-schema permissions are read|invoke|write|propose). These require an
explicit human gate. Propose the change (open an issue/PR) instead of applying.
EOF
    exit 2
  fi
fi

# --- 2. Locate the grant -----------------------------------------------------
grant_file=""
for candidate in \
  "${COGITAVE_GRANT_FILE:-}" \
  "./.cogitave/grant.json" \
  "./agents/identity/grant.json"; do
  [ -n "$candidate" ] || continue
  if [ -f "$candidate" ]; then
    grant_file="$candidate"
    break
  fi
done

if [ -z "$grant_file" ]; then
  echo "validate-grant: no CapabilityGrant found (set COGITAVE_GRANT_FILE). Day-0 advisory: allowing, but the action is unverified against a grant." >&2
  exit 0
fi

# Validate the grant looks like a CapabilityGrant; if malformed, fail closed for
# writes/commands (least privilege == default deny).
kind="$(jq -r '.kind // empty' "$grant_file" 2>/dev/null || true)"
if [ "$kind" != "CapabilityGrant" ]; then
  echo "validate-grant: '$grant_file' is not a CapabilityGrant (kind=$kind). Default-deny." >&2
  exit 2
fi

# --- 3. Determine the needed (resource, permission) --------------------------
# Write/Edit -> need permission 'write' on an fs-path/repo resource matching the
# file. Bash -> need permission 'invoke' on an fs-path/repo/environment; at Day 0
# we only assert the command is grant-covered, not parse its full effect.
need_verb=""
target=""
case "$tool_name" in
  Write | Edit | MultiEdit | NotebookEdit)
    [ -n "$file_path" ] || exit 0
    need_verb="write"
    target="$file_path"
    ;;
  Bash)
    [ -n "$command_str" ] || exit 0
    need_verb="invoke"
    target="$command_str"
    ;;
  *) exit 0 ;;
esac

# --- 4. Match against the grant ----------------------------------------------
# A capability matches when:
#   - it grants $need_verb (or 'propose', which subsumes write-as-proposal), AND
#   - its resource.ref (a path glob / repo slug / host) matches the target.
# Globs are matched with bash case-globbing (fnmatch-style), the same family the
# schema's "path glob" ref uses.
matched=0
constraints_note=""

# Stream each capability as a compact JSON line.
while IFS= read -r cap; do
  [ -n "$cap" ] || continue
  rtype="$(printf '%s' "$cap" | jq -r '.resource.type // empty')"
  rref="$(printf '%s' "$cap" | jq -r '.resource.ref // empty')"
  perms="$(printf '%s' "$cap" | jq -r '(.permissions // []) | join(",")')"
  read_only="$(printf '%s' "$cap" | jq -r '.constraints.readOnly // false')"

  # Permission must include the needed verb (propose subsumes write).
  case ",$perms," in
    *",$need_verb,"*) : ;;
    *",propose,"*)
      [ "$need_verb" = "write" ] || continue
      constraints_note="grants 'propose' (propose-only)" ;;
    *) continue ;;
  esac

  # readOnly constraint forbids write.
  if [ "$read_only" = "true" ] && [ "$need_verb" = "write" ]; then
    continue
  fi

  # Resource-type relevance: fs-path/repo for writes; also environment/net for
  # commands. mcp-tool/mcp-resource refs are not file/command targets here.
  case "$rtype" in
    fs-path | repo | environment | net-endpoint) : ;;
    *) continue ;;
  esac

  [ -n "$rref" ] || continue

  # Glob match: does the target fall under the granted ref?
  # shellcheck disable=SC2254  # intentional glob from grant data
  case "$target" in
    $rref | $rref/* | *"$rref"*)
      matched=1
      break
      ;;
  esac
done < <(jq -c '.capabilities[]?' "$grant_file")

if [ "$matched" -eq 1 ]; then
  [ -n "$constraints_note" ] && echo "validate-grant: in-grant ($constraints_note)." >&2
  exit 0
fi

# --- 5. Out of grant: block --------------------------------------------------
agent_uid="$(jq -r '.subject.agentUid // "unknown-agent"' "$grant_file")"
cat >&2 <<EOF
validate-grant: BLOCKED — action is outside the agent's capability grant.

  agent:   ${agent_uid}
  action:  ${tool_name} (needs '${need_verb}')
  target:  ${target}
  grant:   ${grant_file}

Least privilege is default-deny (AGENTS.md §5): absence of a matching capability
= no authority. Do NOT widen the grant to make this pass. If the task legitimately
needs this resource, request a new/attenuated grant via PR review (CODEOWNER, SoD)
per agents/identity/agent-identity-and-capabilities.md.
EOF
exit 2
