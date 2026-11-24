---
name: park
description: Quiesce this Claude Code session. Find background shells, monitors, subagents, crons, wakeup loops, hooks, MCP channels and other wake sources; offer to stop them; then hand off to /compact so the session sits with no further usage. Use when the user says /park or asks to park, idle or quiesce the session.
disable-model-invocation: true
---

# Park the session

Goal: after this skill finishes, nothing this session controls can
start another model turn on its own.  Only a new message from the user
(terminal or Remote Control) or a peer session should wake it.

Be terse.  Do not narrate.  Do not schedule anything.

## 1. Inventory wake sources

Check every item; run independent checks in parallel.

| Source | How to find | How to stop |
|---|---|---|
| Background Bash tasks | task IDs from this conversation's `run_in_background` results; process tree below | `TaskStop` with the task ID; `kill` an orphan PID only with consent |
| Monitors | `Monitor` calls in this conversation | `TaskStop` |
| Subagents / forks | `ListAgents` (in-process rows only) | `TaskStop` |
| Session crons | `CronList` | `CronDelete` |
| /loop wakeups | `ScheduleWakeup` calls in this conversation | `ScheduleWakeup` with `stop: true` |
| Queued notifications | `ReadNotifications` until 0 remaining | read = drained; quote non-routine ones (see 2) |
| Idle-notice subscriptions | `SendMessage` calls with `notify_when_idle` | cannot cancel; report |
| Artifact watches | publish results that said the session watches an artifact | `ArtifactComments` unwatch if offered; else report |
| Hooks | `hooks` keys in `~/.claude/settings.json`, `~/.claude/settings.local.json`, `.claude/settings.json`, `.claude/settings.local.json`, and enabled plugins | report; edit settings only with explicit consent |
| MCP channels | connected MCP servers / plugins that push inbound messages (Slack, Telegram, webhooks, other channels); `claude mcp list` and enabled plugins | report; user disconnects via `/mcp` or settings, with consent |
| Cloud routines | `RemoteTrigger` list, if available | report only: they bill on their own, not via this session |

Load deferred tools with `ToolSearch` (`select:<name>`) before use.
Skip a check whose tool is unavailable, and say so.

### Process tree

Background tasks usually run under a wrapper shell, so list all
descendants of the `claude` process, not just direct children.
Portable (Linux and macOS):

```sh
p=$$
while [ "$p" -gt 1 ]; do
  case "$(ps -o comm= -p "$p")" in *claude*) break ;; esac
  p=$(ps -o ppid= -p "$p" | tr -d ' ')
done
ps -eo pid=,ppid=,etime=,command= | awk -v root="$p" -v self="$$" '
  { line[$1] = $0; kids[$2] = kids[$2] " " $1; parent[$1] = $2 }
  END {
    for (a = self; a != "" && a != root; a = parent[a]) mine[a] = 1
    n = split(kids[root], q, " ")
    for (i = 1; i <= n; i++) {
      x = q[i]
      if (x in mine) continue
      print line[x]
      m = split(kids[x], k, " ")
      for (j = 1; j <= m; j++) q[++n] = k[j]
    }
  }'
```

`mine` skips this command's own shell and its wrappers.  If the walk reaches PID 1
without matching, the binary has another name (e.g. `node`); say so
and fall back to task IDs.  MCP server processes are expected
children; do not offer to kill them.

### Hooks

Hooks matter only if they can start a turn without user input.  Flag
these specifically:

- **Stop / SubagentStop hooks**: the park turn itself fires them.  One
  that returns a block decision (or exits 2) restarts the session the
  moment this skill finishes.  Show its command.
- Async or rewake hooks, and Notification hooks that inject messages.

Hooks that run only on the user's prompts or tool calls cost nothing
while parked; list them as harmless.

## 2. Report and offer

Print one compact table: source, item, state, wakes session (y/n).
Quote verbatim any drained notification that is not routine (e.g. a
failed build, a review comment, a peer request); the user will not see
it elsewhere.

If anything can wake the session, use `AskUserQuestion` (single
select) with these options:

- "Stop all (Recommended)": stop every stoppable item.
- "Choose individually": print the stoppable items as a numbered list
  and end the turn; stop the ones the user names in their reply.
- "Leave running": stop nothing.

Never stop or edit anything without the user's answer.  Re-check
stopped items once to confirm.

## 3. Hand off

If nothing that can wake the session remains (or the user chose to
leave items running knowingly), end the turn with exactly:

    Parked.  Run /compact now; nothing will wake this session after that.
    Check /usage in an hour to confirm it hasn't moved.

followed by any items left running.  A skill cannot run built-in
commands, so /compact must come from the user; compaction itself costs
one summarization, after which the session accrues nothing until a new
message arrives.

Do not call any tool after printing those lines.

## Caveats to state only if relevant

- Remote Control and peer sessions can still deliver messages; each
  message starts a turn.  Turning RC off (`/remote-control`) is the
  only way to rule that out.
- GitHub PR subscriptions, if any, can deliver notifications; report
  them.
