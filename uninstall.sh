#!/usr/bin/env bash
# uninstall.sh — remove cc-session-title from ~/.claude. Mac-native.
set -euo pipefail

CLAUDE_DIR="${CLAUDE_DIR:-$HOME/.claude}"
HOOKS_DIR="$CLAUDE_DIR/hooks"
SKILLS_DIR="$CLAUDE_DIR/skills"
SETTINGS="$CLAUDE_DIR/settings.json"
HOOK_CMD="$HOOKS_DIR/cc-session-title.sh"

rm -f "$HOOKS_DIR/cc-session-title.sh"
rm -f "$HOOKS_DIR/cc-session-title-generate.sh"
rm -f "$HOOKS_DIR/cc-session-title-set.sh"
rm -rf "$SKILLS_DIR/cc-session-title"

if [[ -f "$SETTINGS" ]] && command -v python3 >/dev/null 2>&1; then
    cp "$SETTINGS" "$SETTINGS.bak.$(date +%Y%m%d-%H%M%S)"
    python3 - "$SETTINGS" "$HOOK_CMD" <<'PY'
import json, sys

path, cmd = sys.argv[1], sys.argv[2]
with open(path) as f:
    cfg = json.load(f)

# Drop our entries from every hooks event array; remove now-empty arrays.
hooks = cfg.get('hooks')
if isinstance(hooks, dict):
    for event, arr in list(hooks.items()):
        if not isinstance(arr, list):
            continue
        cleaned = []
        for entry in arr:
            if not isinstance(entry, dict):
                cleaned.append(entry); continue
            inner = [h for h in entry.get('hooks', [])
                     if not (isinstance(h, dict) and h.get('command') == cmd)]
            if inner:
                entry['hooks'] = inner
                cleaned.append(entry)
        if cleaned:
            hooks[event] = cleaned
        else:
            del hooks[event]
    if not hooks:
        del cfg['hooks']

# Drop our env var; drop the env block entirely if it ends up empty.
env = cfg.get('env')
if isinstance(env, dict) and 'CLAUDE_CODE_DISABLE_TERMINAL_TITLE' in env:
    del env['CLAUDE_CODE_DISABLE_TERMINAL_TITLE']
    if not env:
        del cfg['env']

with open(path, 'w') as f:
    json.dump(cfg, f, indent=2)
    f.write('\n')
PY
fi

echo "cc-session-title uninstalled (settings.json backup left in place)."
