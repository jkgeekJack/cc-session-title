# cc-session-title

Auto-rename your Claude Code terminal tab title in **the language you typed**.

Claude Code's built-in title generator always returns English, even when you
prompt in Chinese / Japanese / 한국어 / Español / etc. This package replaces
that with a small Haiku-powered hook that:

- Disables Claude Code's native title generator (via the official
  `CLAUDE_CODE_DISABLE_TERMINAL_TITLE` env var).
- Fires once on `UserPromptSubmit` per session, calls `claude -p` (Haiku)
  with a system prompt that forces the output language to match the input.
- Writes the result to your terminal via OSC `\033]0;…\007`.
- Restores the saved title on resumed sessions.

## Requirements

macOS only. Uses only:

- `bash`, `plutil`, `mktemp`, `install` — shipped with macOS
- `/usr/bin/python3` — included with Xcode CLT (`xcode-select --install` if missing)
- your existing `claude` CLI (uses your Pro/Max OAuth via keychain — **no
  `ANTHROPIC_API_KEY` required**)

A terminal emulator that honors OSC 0/2: iTerm2, Terminal.app, Alacritty,
Kitty, WezTerm, Ghostty, tmux with `set -g set-titles on`, etc.

## Install

```bash
./install.sh
```

Restart any open Claude Code session. The next session's first prompt will
trigger localized title generation.

To remove:

```bash
./uninstall.sh
```

The installer takes a `settings.json.bak.<ts>` snapshot, is idempotent
(rerun-safe), and only mutates these keys:

| Key | Purpose |
| --- | --- |
| `env.CLAUDE_CODE_DISABLE_TERMINAL_TITLE = "1"` | Turns Claude Code's native `useTerminalTitle` into a no-op (see `src/screens/REPL.tsx:603` upstream) so our hook is the sole writer of the OSC sequence — no race, no flicker. |
| `hooks.UserPromptSubmit[…]` | Registers `~/.claude/hooks/cc-session-title.sh`. |

## How it works

```
first prompt of session
        │
        ▼
~/.claude/hooks/cc-session-title.sh   (UserPromptSubmit)
        │
        │ detached background:
        ▼
~/.claude/hooks/cc-session-title-generate.sh
        │
        │ claude -p --model claude-haiku-4-5
        │   --json-schema {title:string}
        │   --system-prompt "match input lang"
        ▼
write OSC \033]0;<title>\007 to /dev/tty
+ persist to ~/.local/state/claude-code-session-title/<sid>.title
```

On a **resumed** session (`claude --resume <sid>`), the hook re-reads the
saved title file and re-applies the OSC immediately on the first prompt — no
new Haiku call.

## Manual refresh: the `cc-session-title` skill

If the topic drifts mid-session and you want a fresh title, just say:

> 重新生成标题 / refresh title / rename tab

Claude invokes the `cc-session-title` skill, which composes the title in
your input language **using its own conversation context** (no extra Haiku
call — instant) and applies it via `cc-session-title-set.sh`. That helper
shares the same sanitization (control-char strip, 60-char cap, path-shape
rejection) as the auto path, so manual and auto stay consistent.

## Troubleshooting

**Title not updating.** Run the generator manually to see actual errors:

```bash
~/.claude/hooks/cc-session-title-generate.sh test-sid "你的测试 prompt"
cat ~/.local/state/claude-code-session-title/test-sid.title
```

If `claude -p` reports auth required, run `claude auth login`.

**Wipe stored titles.**

```bash
rm -rf ~/.local/state/claude-code-session-title
```

## Files

```
.
├── README.md
├── install.sh                                  # idempotent installer
├── uninstall.sh                                # safe removal
├── hooks/
│   ├── cc-session-title.sh                     # UserPromptSubmit hook
│   ├── cc-session-title-generate.sh            # auto: Haiku-backed generator
│   └── cc-session-title-set.sh                 # manual: apply a pre-composed title
└── skills/
    └── cc-session-title/SKILL.md               # manual /cc-session-title skill
```
