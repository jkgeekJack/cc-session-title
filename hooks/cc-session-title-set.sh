#!/usr/bin/env bash
# cc-session-title-set.sh — apply a pre-composed title.
#
# Usage: cc-session-title-set.sh <session-id> <title>
#
# Used by the cc-session-title skill for manual refresh: the parent Claude
# composes the title in the user's input language directly (it already has
# full conversation context), and this helper just sanitizes and writes it.
#
# Centralizes the same sanitization the auto-generator uses, so manual and
# auto paths stay consistent — minus the Haiku round-trip that made manual
# slow and (because the parent's summary tends toward English) sometimes
# produced wrong-language titles.
set -e

session_id="${1:-}"
title="${2:-}"
[[ -z "$session_id" || -z "$title" ]] && { echo "usage: $0 <session-id> <title>" >&2; exit 1; }

state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/claude-code-session-title"
mkdir -p "$state_dir"

# Defensive: refuse path-shaped values.
case "$title" in /*|*/var/folders/*|*/tmp/*|*/private/*)
    echo "refusing path-shaped title: $title" >&2; exit 1 ;;
esac

# Sanitize and cap (60 chars matches the auto path).
title="${title//$'\033'/}"; title="${title//$'\007'/}"
title="${title//$'\r'/}";   title="${title//$'\n'/ }"
[[ ${#title} -gt 60 ]] && title="${title:0:60}"

printf '%s\n' "$title" > "$state_dir/${session_id}.title"
if [[ -w /dev/tty ]]; then
    printf '\033]0;%s\007' "$title" 2>/dev/null > /dev/tty || true
fi

# Echo the final title so the caller can confirm.
printf '%s\n' "$title"
