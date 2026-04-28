#!/usr/bin/env bash
# install.sh — install the cc-session-title hook + skill into ~/.claude.
# Mac-native: requires only macOS-shipped tools (plutil, /usr/bin/python3)
# plus the user's existing `claude` CLI.
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS="$CLAUDE_DIR/settings.json"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

err() { echo "ERROR: $*" >&2; exit 1; }

command -v plutil  >/dev/null 2>&1 || err "plutil not found — this installer targets macOS."
command -v python3 >/dev/null 2>&1 || err "python3 not found. Install Xcode CLT: xcode-select --install"
command -v claude  >/dev/null 2>&1 || err "claude CLI not found. See https://docs.claude.com/claude-code"

mkdir -p "$HOOKS_DIR" "$SKILLS_DIR/cc-session-title"
install -m 0755 "$REPO_ROOT/hooks/cc-session-title.sh"          "$HOOKS_DIR/cc-session-title.sh"
install -m 0755 "$REPO_ROOT/hooks/cc-session-title-generate.sh" "$HOOKS_DIR/cc-session-title-generate.sh"
install -m 0755 "$REPO_ROOT/hooks/cc-session-title-set.sh"      "$HOOKS_DIR/cc-session-title-set.sh"
install -m 0644 "$REPO_ROOT/skills/cc-session-title/SKILL.md"   "$SKILLS_DIR/cc-session-title/SKILL.md"

[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"

HOOK_CMD="$HOOKS_DIR/cc-session-title.sh"

python3 - "$SETTINGS" "$HOOK_CMD" <<'PY'
import json, sys

path, cmd = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)

# Disable Claude Code's native English-only title generator.
# Source: src/screens/REPL.tsx — `titleDisabled` is gated on this env var.
cfg.setdefault('env', {}).setdefault('CLAUDE_CODE_DISABLE_TERMINAL_TITLE', '1')

# Idempotent register: append our entry only if not already present.
hooks = cfg.setdefault('hooks', {}).setdefault('UserPromptSubmit', [])
already = any(
    h.get('command') == cmd
    for entry in hooks if isinstance(entry, dict)
    for h in entry.get('hooks', []) if isinstance(h, dict)
)
if not already:
    hooks.append({'hooks': [{'type': 'command', 'command': cmd}]})

with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
PY

echo "cc-session-title installed."
echo "  Hook        : $HOOKS_DIR/cc-session-title.sh"
echo "  Generator   : $HOOKS_DIR/cc-session-title-generate.sh"
echo "  Set helper  : $HOOKS_DIR/cc-session-title-set.sh"
echo "  Skill       : $SKILLS_DIR/cc-session-title/SKILL.md"
echo "  Settings   : $SETTINGS"
echo "             + UserPromptSubmit hook"
echo "             + env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE=1"
echo
echo "Restart Claude Code. On the next session's first prompt, the tab"
echo "title will be generated in your input language."
