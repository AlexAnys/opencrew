[中文](../A2A_SETUP_GUIDE.md) | **English**

# Discussion Mode Setup Guide — Independent Bot + Collaboration Mechanism

> Based on 2026-03-30 ~ 2026-04-02 end-to-end testing.
> PR: https://github.com/AlexAnys/opencrew/pull/38

---

## Part 1: How to Introduce an Independent Bot

### Background

OpenCrew defaults to all Agents sharing one Slack App (one bot user). This means Bot A's messages to Bot B's channel are ignored by the self-reply filter (same bot user).

**Discussion Mode** requires "selective independence": give a small number of high-value Agents (e.g., Orchestrator) their own Slack App, then invite them into other Agents' channels for direct conversation.

### Step 1: Create an Independent Slack App

Go to [api.slack.com/apps](https://api.slack.com/apps) → Create New App → **From manifest**:

```json
{
    "display_information": {
        "name": "Your-Bot-Name",
        "description": "OpenClaw Discussion Mode agent"
    },
    "features": {
        "bot_user": {
            "display_name": "Your-Bot-Name",
            "always_online": true
        },
        "app_home": {
            "messages_tab_enabled": true,
            "messages_tab_read_only_enabled": false
        }
    },
    "oauth_config": {
        "scopes": {
            "bot": [
                "chat:write",
                "im:write",
                "channels:history",
                "groups:history",
                "groups:read",
                "im:history",
                "im:read",
                "mpim:history",
                "mpim:read",
                "channels:read",
                "users:read",
                "app_mentions:read",
                "assistant:write",
                "reactions:read",
                "reactions:write",
                "pins:read",
                "pins:write",
                "emoji:read",
                "files:read",
                "files:write"
            ]
        }
    },
    "settings": {
        "event_subscriptions": {
            "bot_events": [
                "app_mention",
                "message.channels",
                "message.groups",
                "message.im",
                "message.mpim",
                "reaction_added",
                "reaction_removed",
                "member_joined_channel",
                "member_left_channel",
                "channel_rename",
                "pin_added",
                "pin_removed"
            ]
        },
        "socket_mode_enabled": true,
        "org_deploy_enabled": false,
        "is_hosted": false,
        "token_rotation_enabled": false
    }
}
```

After creation:
1. Basic Information → App-Level Tokens → Generate Token (scope: `connections:write`) → get `xapp-...`
2. Install to Workspace → get `xoxb-...`
3. Record the Bot User ID (Settings → Basic Info, or check the bot's profile in Slack)

### Step 2: Configure OpenClaw Multi-Account

> **Hard requirement: You MUST also declare `accounts.default`**
>
> `account-helpers.ts:listAccountIds()` logic: once an `accounts` object exists with any key, OpenClaw **only starts explicitly declared accounts** — it no longer implicitly creates a default.
>
> If you only add `accounts.new-bot` without `accounts.default`, the main bot's provider won't start, and all existing Agent Slack connections will go down.
>
> This is by design, not a bug.

**Correct config** (incremental changes to `openclaw.json`):

```jsonc
{
  "channels": {
    "slack": {
      // Keep top-level tokens as fallback
      "botToken": "xoxb-main-...",
      "appToken": "xapp-main-...",

      // ★ Critical: explicitly declare accounts.default
      "accounts": {
        "default": {
          "botToken": "xoxb-main-...",   // same as top-level
          "appToken": "xapp-main-..."    // same as top-level
        },
        "new-bot": {
          "botToken": "xoxb-new-...",
          "appToken": "xapp-new-...",
          "channels": {
            "<TARGET_CHANNEL_ID>": {
              "allow": true,
              "requireMention": true,    // only respond to explicit @mentions
              "allowBots": true          // can see other bots' messages
            }
          }
        }
      },

      // Enable allowBots on target channel (so existing Agents see the new bot's messages)
      "channels": {
        "<TARGET_CHANNEL_ID>": {
          "allow": true,
          "requireMention": true,        // recommended: change to true (see Part 2)
          "allowBots": true
        }
      }
    }
  },

  // New bot's routing binding
  "bindings": [
    // ★ Place before existing peer binding for the target channel (more specific match first)
    {
      "agentId": "main",
      "match": {
        "channel": "slack",
        "accountId": "new-bot",
        "peer": { "kind": "channel", "id": "<TARGET_CHANNEL_ID>" }
      }
    },
    // Existing bindings unchanged
    {
      "agentId": "ops",
      "match": {
        "channel": "slack",
        "peer": { "kind": "channel", "id": "<TARGET_CHANNEL_ID>" }
      }
    }
  ]
}
```

### Step 3: Invite Bot and Verify

1. In the target channel: `/invite @Your-Bot-Name`
2. After writing config, **wait for hot-reload** (don't SIGTERM immediately — hot-reload auto-detects changes)
3. Check gateway logs for both providers starting:

```
[slack] [default] starting provider     ✅
[slack] [new-bot] starting provider     ✅
channels resolved: ...(no missing_scope)  ✅
socket mode connected                    ✅ (appears twice)
```

### Rollback

```bash
cp ~/.openclaw/openclaw.json.bak-before-xxx ~/.openclaw/openclaw.json
# Wait for hot-reload, or:
launchctl kill SIGTERM gui/501/ai.openclaw.gateway
```

### Known Pitfalls

| Pitfall | Consequence | Prevention |
|---------|-------------|------------|
| Only add `accounts.new-bot` without `accounts.default` | Main bot disconnects, all Agents lose Slack | Must declare default simultaneously |
| SIGTERM immediately after config write | Hot-reload's in-memory fix gets killed | Wait for hot-reload to complete before verifying |
| New Slack App missing scopes | `channels resolved` reports `missing_scope` | Use the complete manifest above |
| Binding order wrong | New bot's messages route to wrong agent | accountId+peer binding before peer-only binding |

---

## Part 2: Collaboration Mechanism After Introduction

### Core Challenge

Two bots in the same Slack thread encounter three problems:
1. **Double response**: A human posts one message, both bots reply
2. **Loops**: Bot A replies → Bot B gets triggered and replies → Bot A triggered again → ∞
3. **No routing**: No mechanism to determine "who should reply, who should stay silent"

### Why Config Alone Isn't Enough (Source Code Verified)

| Config Option | Expected | Actual |
|---|---|---|
| `requireMention: true` | Only respond to explicit @mentions in thread | ❌ Once a bot has replied in a thread, `implicitMention` is permanently true, bypassing requireMention |
| `allowBots: "mentions"` | Only process bot messages that explicitly @mention this bot | ❌ Slack provider only does truthy/falsy check; `"mentions"` equals `true` (only Discord supports this properly) |

**Source code evidence** (`resolveMentionGating`):

```js
implicitMention = !isDirectMessage && botUserId && message.thread_ts &&
    (message.parent_user_id === botUserId || hasSlackThreadParticipation(...))
// → once bot has participated in thread, implicitMention is permanently true
// → requireMention: true is permanently bypassed
```

### Solution: Two-Layer Defense

#### Layer 1: Config — `requireMention: true` (Channel-level, hard constraint)

```jsonc
"<CHANNEL_ID>": {
  "allow": true,
  "requireMention": true,   // effective for channel root messages
  "allowBots": true
}
```

**Effect**: Channel root messages require explicit @ to trigger → only the @mentioned bot enters the thread.
**Limitation**: Ineffective inside threads (implicitMention bypasses it).

#### Layer 2: Prompt Rules — Explicit @mention Protocol (Thread-level, soft constraint)

Add to every Agent participating in Discussion Mode:

```markdown
## Multi-Agent Thread Collaboration Rules

When in a Slack thread where other bots are also present:

1. **Explicit @mention check**: Check the raw message text for `<@YOUR_BOT_ID>`.
   If NOT present → respond with ONLY `NO_REPLY` — no explanation, no reasoning.

2. **Always @mention your target**: When sending a message to another bot,
   include `<@targetBotID>`. No @mention = conversation end signal.

3. **Role discipline**:
   - Coordinator (initiator): choose @Worker / @Human / nobody (end)
   - Worker (executor): every reply must @mention the Coordinator

4. **Termination**: After "done/conclusion", stop unless re-@mentioned.

5. **Round limit**: Max 8 rounds per thread. After that, pause and summarize to human.
```

### Collaboration Flow (Integrating Anthropic Harness Design)

Drawing from the **dual-role architecture** of Anthropic's Harness Design:

```
User → @Orchestrator: "Investigate XXX"

Orchestrator outputs DISCUSSION SPEC (Phase 0):
  → 📁 discussions/<topic>/spec.md (goals + acceptance criteria + termination conditions)
  → Thread message: "Expanded spec, N acceptance criteria. @Worker please start..."

Round 1:
  Orchestrator → @Worker: specific question
  Worker → @Orchestrator: summary + 📁 round-1.md (detailed analysis)
  Thread messages are summaries only

Round 2:
  Orchestrator evaluates → 📁 review-1.md → @Worker feedback
  ...

Termination (one of three):
  ✅ All acceptance criteria met → DISCUSSION_CLOSE
  ⚠️ Max rounds reached → ask human to intervene
  🔄 No progress for 2 consecutive rounds → ask human to intervene
```

**Key principles**:
1. **Files are the primary communication channel** — Thread holds summaries and @mention routing; detailed work goes in files
2. **Spec before discussion** — Orchestrator's first message must define acceptance criteria and termination conditions
3. **Self-review fails, must separate** — Orchestrator doesn't generate solutions, only coordinates and evaluates
4. **Formal A2A tasks use `sessions_send`** — Discussion action items execute through Delegation with hard `maxPingPongTurns` (0-5)

### Termination Mechanisms

| Layer | Mechanism | Type |
|-------|-----------|------|
| Prompt | @mention protocol + Round N/M counting + DISCUSSION_CLOSE | Soft constraint (instruction following) |
| Config | `requireMention: true` (channel root messages) | Hard constraint (system-level) |
| Config | `loopDetection.pingPong: true` | Hard constraint (tool-call level) |
| A2A | `maxPingPongTurns` (sessions_send) | Hard constraint (system-level) |

### Known Limitations

1. **Input tokens still consumed** — Messages are delivered to all bots; prompt rules only make the agent reply NO_REPLY, but input token cost is unavoidable
2. **Prompts are soft constraints** — LLMs may occasionally violate rules (especially in complex contexts)
3. **`allowBots: "mentions"` is Discord-only** — Slack needs OpenClaw code changes to support this
4. **`requireMention: true` bypassed in threads** — `implicitMention` (thread participation) permanently bypasses it; OpenClaw would need a `thread.requireExplicitMention` option for system-level enforcement

---

## Platform Capability Comparison

| Capability | Slack | Discord | Feishu |
|------------|-------|---------|--------|
| Delegation (sessions_send) | ✅ | ✅ | ✅ |
| Discussion (cross-bot dialogue) | ✅ Verified | ❌ (OpenClaw bug) | ❌ (Platform limitation) |
| `allowBots: "mentions"` | ❌ (Not supported) | ✅ | N/A |
| `requireMention` in thread | ❌ (implicitMention bypass) | ❌ (Same issue) | N/A |
| Multi-Account | ✅ | ✅ | ✅ |
| Hard round control | sessions_send only | sessions_send only | sessions_send only |

---

> 📖 Related → [A2A Protocol v2](../../shared/A2A_PROTOCOL.md) · [Core Concepts](CONCEPTS.md) · [Agent Onboarding](AGENT_ONBOARDING.md)
