#!/usr/bin/env bash
# cc-session-title.sh — UserPromptSubmit hook for Claude Code.
#
# On first prompt of a session: kicks off async title generation in the
# user's input language and writes the result via OSC to /dev/tty.
# On a resumed session: restores the saved title immediately.
#
# Mac-native: depends only on bash + plutil (ships with macOS).
set -e

# Anti-recursion: the generator sets this before calling `claude -p`.
[[ "${CC_SESSION_TITLE_GUARD:-}" == "1" ]] && exit 0

input=$(cat)
[[ -z "$input" ]] && exit 0

event=$(printf '%s' "$input" | plutil -extract hook_event_name raw -o - - 2>/dev/null || true)
[[ "$event" == "UserPromptSubmit" ]] || exit 0

session_id=$(printf '%s' "$input" | plutil -extract session_id raw -o - - 2>/dev/null || true)
[[ -z "$session_id" ]] && exit 0

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code-session-title"
mkdir -p "$state_dir"
title_file="$state_dir/${session_id}.title"
flag_file="$state_dir/${session_id}.started"

write_title() {
    local t="$1"
    [[ -z "$t" ]] && return 0
    # Defensive: refuse path-shaped values (catches any stale or corrupted
    # state file before it gets re-asserted to the tab title).
    case "$t" in /*|*/var/folders/*|*/tmp/*|*/private/*) return 0 ;; esac
    t="${t//$'\033'/}"; t="${t//$'\007'/}"; t="${t//$'\r'/}"; t="${t//$'\n'/ }"
    [[ -w /dev/tty ]] || return 0
    # Redirect order matters: `2>/dev/null` first swallows bash's
    # "Device not configured" if /dev/tty open fails.
    printf '\033]0;%s\007' "$t" 2>/dev/null > /dev/tty || true
}

# Resumed session: title_file already exists from a previous run — restore it.
if [[ -f "$title_file" ]]; then
    write_title "$(cat "$title_file" 2>/dev/null)"
fi

# First prompt of this session: kick off generation.
if [[ ! -f "$flag_file" ]]; then
    prompt=$(printf '%s' "$input" | plutil -extract prompt raw -o - - 2>/dev/null || true)
    [[ -z "$prompt" ]] && exit 0
    : > "$flag_file"

    generator="$(dirname "$0")/cc-session-title-generate.sh"
    [[ -x "$generator" ]] || exit 0
    (
        CC_SESSION_TITLE_GUARD=1 "$generator" "$session_id" "$prompt"
    ) </dev/null >/dev/null 2>&1 &
    disown 2>/dev/null || true
fi

exit 0
