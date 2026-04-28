---
name: cc-session-title
description: Refresh the Claude Code terminal tab title for the current session. Trigger on 更新标题, 重命名标签, 重新生成标题, refresh tab title, rename session, fix the tab title.
---

When the user asks to refresh the current session's tab title:

1. **Compose the title yourself, in the user's actual input language.**
   You already have the full conversation in context — pick a 3-7 word title
   (max 40 chars) that captures the current topic. **Do not call
   `cc-session-title-generate.sh` for the manual path** — that spawns a fresh
   Haiku inference (slow), and the summary you'd pass to it tends to drift
   into English, which is exactly the bug to avoid.

   Match the language of the user's recent prompts:
   - 中文输入 → 中文标题（自然形式）
   - 日本語入力 → 日本語タイトル
   - English input → sentence case (e.g. "Refactor API client error handling")
   - Other languages → natural form for that language

2. **Determine the current session_id**: env `CLAUDE_SESSION_ID` if set,
   otherwise the basename (without `.jsonl`) of the latest file under
   `~/.claude/projects/<sanitized-cwd>/`.

3. **Apply it instantly** via the helper (sanitizes + writes OSC + state):

   ```bash
   ~/.claude/hooks/cc-session-title-set.sh "$session_id" "$title"
   ```

4. **Confirm in one short sentence**, in the user's language:
   `Tab title updated to: <title>` / `已将标签标题更新为：<title>` / etc.

The helper rejects path-shaped values, strips control chars, and caps length
at 60 chars — same sanitization as the auto path, so manual and auto stay
consistent.
