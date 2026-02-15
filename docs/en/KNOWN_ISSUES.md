[中文](../KNOWN_ISSUES.md) | **English**

# Known Issues & Current Best Practices

> Purpose: Honestly document the system's real boundaries and provide stable workarounds **without modifying source code**.

---

## P0: Root messages in a Slack channel share a single session by default (context contamination)

### Symptoms

In OpenCrew's Slack routing, the **channel session key** defaults to:

- `agent:<agentId>:slack:channel:<channelId>`

This means: multiple **unrelated root messages** in the same channel may share the same channel-level session context.

### What can existing configuration do?

- `replyToMode: "all"` ensures replies go into threads
- `channels.slack.thread.historyScope = "thread"` + `inheritParent=false` ensures history isolation within threads

But they **cannot automatically turn each new root message into a new session**.

### Current stable approach (no source changes, recommended)

- **Define "tasks" as threads**: Push every task forward inside a thread
- Only post short root messages in the channel as anchors (a one-line title/task summary), then immediately continue the conversation in the thread
- Running multiple tasks in parallel in the same channel: open multiple threads

### Advanced (not recommended for beginners): dist-level patch

The `patches/slack-thread-routing.sh` in this repo only provides a conceptual approach and rollback skeleton. It is not guaranteed to work across all versions.

Reason: OpenCrew's dist bundling structure changes between versions. A reliable patch requires version detection + precise code targeting.

Conclusion: **The open-source version does not depend on patches by default.** If you can provide a stable, reproducible implementation, PRs are welcome.

---

## P1: A2A visibility gap (no reply in Slack thread after task dispatch)

### Symptoms

After `sessions_send` fires, the target agent occasionally does not reply in the expected Slack thread, leaving users seeing "task was dispatched but nobody picked it up."

### Current mechanism: A2A visibility contract (document-level fallback)

OpenCrew uses a "two-step trigger":
1. Create a Slack root message in the target channel (a visible anchor)
2. Use `sessions_send` to trigger the target agent, executing within that thread's sessionKey

The sender is required to check whether a reply appears in the thread after sending. If not, mark it as `failed-delivery` and escalate.

> This is a "contractual fallback," not a root-cause fix. A true fix requires stronger determinism from upstream regarding Slack deliveryContext.

---

## P1: Context pressure on long tasks (context overflow)

### Symptoms

Long-running threads with large tool outputs can cause context overflow.

### Current best practices

- More than 20 turns or spanning multiple days: write a Checkpoint
- Every A/P/S task must have a Closeout (10-15 lines)
- Use spawn for parallel subtasks (isolates context)

---

## P2: Cross-session semantic retrieval in the knowledge system is still exploratory

The current v1 relies on Closeout + KO distillation. Cross-session semantic retrieval/indexing is an exploratory direction (contributions welcome).
