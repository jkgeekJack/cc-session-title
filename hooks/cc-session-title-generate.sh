#!/usr/bin/env bash
# cc-session-title-generate.sh — Haiku-backed title generator.
#
# Usage: cc-session-title-generate.sh <session-id> <prompt>
#
# Calls `claude -p` (uses the user's existing OAuth via keychain — no
# ANTHROPIC_API_KEY required) with a system prompt that forces the output
# language to match the input language. Writes the result to:
#   - the controlling terminal via OSC 0
#   - ~/.local/state/claude-code-session-title/<sid>.title
#
# CC_SESSION_TITLE_GUARD=1 must be set by the caller to suppress the
# UserPromptSubmit hook recursion that would otherwise fire when the
# inner `claude -p` submits its own user message.
#
# Mac-native: depends on bash + plutil (system) + claude (user's CLI).
set -e

session_id="${1:-}"
prompt="${2:-}"
[[ -z "$session_id" || -z "$prompt" ]] && exit 0

command -v claude >/dev/null 2>&1 || exit 0
command -v plutil >/dev/null 2>&1 || exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code-session-title"
mkdir -p "$state_dir"
title_file="$state_dir/${session_id}.title"

read -r -d '' SYSTEM_PROMPT <<'PROMPT' || true
You generate concise tab titles for a coding-assistant session.

Hard rules:
- 3-7 words. Maximum 40 characters.
- MATCH THE LANGUAGE OF THE INPUT exactly.
  Chinese input -> Chinese title.
  Japanese input -> Japanese title.
  Korean / French / Spanish / etc. -> same language.
  English input -> English title.
- For English use sentence case (capitalize first word and proper nouns only).
- For other languages use natural form.
- Capture the main topic or goal. Be specific, not vague.
- Return JSON with a single "title" field. No prose, no clarification questions.

Examples:
Input: "fix the login button on mobile"
Output: {"title": "Fix login button on mobile"}

Input: "帮我修一下移动端登录按钮"
Output: {"title": "修复移动端登录按钮"}

Input: "OAuth認証の追加をお願いします"
Output: {"title": "OAuth認証を追加"}

Input: "ayuda a refactorizar el cliente API"
Output: {"title": "Refactorizar cliente API"}
PROMPT

# Cap input to keep token cost bounded.
[[ ${#prompt} -gt 2000 ]] && prompt="${prompt:0:2000}"

# `claude -p --json-schema ...` returns the parsed object under
# `.structured_output`, NOT `.result` (which stays empty in schema mode).
# Flags:
#   --tools ''                    disable tools (must precede `--` because
#                                 it's variadic — `--` ends flag parsing)
#   --disable-slash-commands      skip skill resolution
#   --no-session-persistence      don't write a transcript for this throwaway call
[[ -n "${CC_SESSION_TITLE_DEBUG:-}" ]] && exec 2>>"$state_dir/debug.log"

title=$(claude -p \
    --model claude-haiku-4-5 \
    --output-format json \
    --json-schema '{"type":"object","properties":{"title":{"type":"string"}},"required":["title"],"additionalProperties":false}' \
    --system-prompt "$SYSTEM_PROMPT" \
    --tools '' \
    --disable-slash-commands \
    --no-session-persistence \
    -- "$prompt" 2>/dev/null \
    | plutil -extract structured_output.title raw -o - - 2>/dev/null) || true

[[ -z "$title" ]] && exit 0

# Defensive: refuse path-shaped values (catches any future parsing bug
# before it overwrites the user's tab title with a temp path).
case "$title" in
    /*|*/var/folders/*|*/tmp/*|*/private/*) exit 0 ;;
esac

# Sanitize and cap.
title="${title//$'\033'/}"; title="${title//$'\007'/}"
title="${title//$'\r'/}";   title="${title//$'\n'/ }"
[[ ${#title} -gt 60 ]] && title="${title:0:60}"

printf '%s\n' "$title" > "$title_file"

if [[ -w /dev/tty ]]; then
    printf '\033]0;%s\007' "$title" 2>/dev/null > /dev/tty || true
fi

exit 0
