[中文](../A2A_SETUP_GUIDE.md) | **English**

# Discussion Mode Setup Guide

> Based on 2026-03-30 ~ 2026-04-02 end-to-end testing, covering configuration flow + collaboration mechanism + known pitfalls.
> PR: https://github.com/AlexAnys/opencrew/pull/38

This guide has three parts:
- **Part 1**: Agent Configuration Guide (generic, parameterized -- for any OpenClaw agent to execute)
- **Part 2**: Human Operations (create Slack App, one-time)
- **Part 3**: Collaboration Mechanism After Introduction

---

## Part 1: Agent Configuration Guide (To Agent)

> The following is the complete procedure an OpenClaw agent should follow when helping a user configure Discussion Mode.
> All identifiers are parameterized -- fill them in dynamically based on the user's actual config.

### Prerequisites (User Must Complete in Advance)

The user must provide:
- Bot Token (`xoxb-...`) and App Token (`xapp-...`) for the new Slack App
- The agent ID the new bot should be associated with (e.g., `orchestrator`, `cos`, `ali`, etc.)
- The target channel(s) the new bot should join
- Confirmation that the user has run `/invite @NewBot` in the target channel(s) in Slack

### Step 0: Read Current Config (Must Do First)

Before modifying any config, read `openclaw.json` and record:

```
Information to confirm:
1. Do channels.slack.botToken and appToken exist? (main bot credentials)
2. Does channels.slack.accounts already exist?
   - If yes: what keys are present? Is there already an accounts.default?
   - If no: currently in single-account mode
3. What channels exist in channels.slack.channels and their current config?
4. What existing bindings are there?
```

### Step 1: Back Up

```bash
cp ~/.openclaw/openclaw.json ~/.openclaw/openclaw.json.bak-before-<description>-<YYYYMMDD>
```

### Step 2: accounts.default Guard (Hard Rule)

> **This guard cannot be skipped. Violation will disconnect all existing Agents.**
>
> OpenClaw's `listAccountIds()` logic: once an `accounts` object exists with any key,
> **only explicitly declared accounts are started** -- the implicit default provider is no longer created.
>
> Lesson learned: omitting accounts.default caused ~13 hours of total Agent disconnection.

**Decision logic**:

```
IF channels.slack.accounts does not exist (single-account mode):
    -> When creating the accounts object, you MUST include accounts.default
    -> accounts.default.botToken = current channels.slack.botToken
    -> accounts.default.appToken = current channels.slack.appToken

IF channels.slack.accounts already exists:
    IF accounts.default already exists:
        -> Safe, continue
    ELSE:
        -> STOP! Add accounts.default before proceeding
```

### Step 3: Add New Account

Add the new account under `channels.slack.accounts`:

```jsonc
"accounts": {
    "default": { ... },  // <- Step 2 ensures this exists
    "<ACCOUNT_ID>": {     // <- user-specified account identifier (e.g. "orchestrator")
        "botToken": "<user-provided xoxb-...>",
        "appToken": "<user-provided xapp-...>",
        "channels": {
            // For each target channel:
            "<CHANNEL_ID_1>": {
                "allow": true,
                "requireMention": true,  // new bot only responds to explicit @mention
                "allowBots": true        // new bot can see other bots' messages
            },
            "<CHANNEL_ID_2>": {
                "allow": true,
                "requireMention": true,
                "allowBots": true
            }
            // ... all user-specified channels
        }
    }
}
```

### Step 4: Update Target Channel Global Config

For each channel the new bot will join, add `allowBots: true` in `channels.slack.channels`:

```jsonc
"channels": {
    "<CHANNEL_ID_1>": {
        "allow": true,       // keep existing value
        // ... keep all other existing config
        "allowBots": true    // <- new: lets the channel's existing agents see the new bot's messages
    }
}
```

**Note**: Do not overwrite the channel's other existing config (`requireMention`, `users`, `systemPrompt`, etc.). Only incrementally add `allowBots`.

### Step 5: Add Routing Binding

Add a binding for each target channel of the new account.

**Binding type selection**:

```
If the new bot routes to the same agent across all channels:
    -> Use a single account-level binding (no peer)
    { "agentId": "<AGENT_ID>", "match": { "channel": "slack", "accountId": "<ACCOUNT_ID>" } }

If the new bot routes to different agents in different channels:
    -> One accountId+peer binding per channel
    { "agentId": "<AGENT_ID>", "match": { "channel": "slack", "accountId": "<ACCOUNT_ID>", "peer": { "kind": "channel", "id": "<CHANNEL_ID>" } } }
```

**Binding order**: Insert new bindings **before existing same-channel bindings** in the `bindings` array (more specific matches take priority).

### Step 6: Write Config and Wait for Hot Reload

```bash
# Write openclaw.json (ensure valid JSON)
# Do NOT SIGTERM -- wait for hot reload to take effect automatically
```

### Step 7: Verify

Check gateway logs (`~/.openclaw/logs/gateway.log`) and confirm **all** of the following:

```
[slack] [default] starting provider        — main bot still running
[slack] [<ACCOUNT_ID>] starting provider   — new bot started
channels resolved: ...(no missing_scope)   — all channel permissions OK
socket mode connected (appears N times, N = number of accounts) — connection successful
```

**If verification fails**:

```
If only the default provider starts and the new account does not:
    -> Check if the new account's tokens are correct
    -> Check if the new Slack App has Socket Mode enabled

If the default provider does not start:
    -> accounts.default is missing! Roll back immediately:
    cp ~/.openclaw/openclaw.json.bak-before-... ~/.openclaw/openclaw.json

If missing_scope appears:
    -> User needs to add the corresponding scope in the Slack App and Reinstall
```

### Config Template (Full Reference)

```jsonc
// openclaw.json -- Discussion Mode incremental config
{
    "channels": {
        "slack": {
            // Top-level tokens retained (as fallback)
            "botToken": "xoxb-main-...",
            "appToken": "xapp-main-...",

            "accounts": {
                // Must exist
                "default": {
                    "botToken": "xoxb-main-...",
                    "appToken": "xapp-main-..."
                },
                // New account
                "<ACCOUNT_ID>": {
                    "botToken": "xoxb-new-...",
                    "appToken": "xapp-new-...",
                    "channels": {
                        "<CHANNEL_ID>": {
                            "allow": true,
                            "requireMention": true,
                            "allowBots": true
                        }
                    }
                }
            },

            "channels": {
                "<CHANNEL_ID>": {
                    "allow": true,
                    "allowBots": true
                }
            }
        }
    },

    "bindings": [
        // New account binding (place first)
        {
            "agentId": "<AGENT_ID>",
            "match": {
                "channel": "slack",
                "accountId": "<ACCOUNT_ID>"
            }
        },
        // Existing bindings (unchanged)
        // ...
    ]
}
```

### Rollback

```bash
# Method 1: Restore backup (recommended)
cp ~/.openclaw/openclaw.json.bak-before-... ~/.openclaw/openclaw.json
# Wait for hot reload, or:
launchctl kill SIGTERM gui/501/ai.openclaw.gateway

# Method 2: Manual rollback
# Remove accounts.<ACCOUNT_ID>
# If only default remains under accounts, you can delete the entire accounts object to restore single-account mode
# Remove corresponding bindings
# Remove allowBots from channels (if it wasn't there before)
```

---

## Part 2: Human Operations (Create Slack App)

The user needs to create an independent Slack App at [api.slack.com/apps](https://api.slack.com/apps).

### Recommended Manifest

Create New App -> **From manifest** -> paste the following (modify `name` and `description`):

```json
{
    "display_information": {
        "name": "<Your Bot Name>",
        "description": "OpenClaw Discussion Mode agent"
    },
    "features": {
        "bot_user": {
            "display_name": "<Your Bot Name>",
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
                "channels:history",
                "channels:read",
                "groups:history",
                "groups:read",
                "users:read",
                "app_mentions:read",
                "reactions:read",
                "reactions:write",
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
                "message.mpim"
            ]
        },
        "socket_mode_enabled": true,
        "org_deploy_enabled": false,
        "is_hosted": false,
        "token_rotation_enabled": false
    }
}
```

> **Minimal scope note**: The scopes above are the minimum required for Discussion Mode. If you need DM, pins, or other additional features, refer to `docs/SLACK_SETUP.md` for the full list.

After creation:
1. **App-Level Token**: Basic Information -> App-Level Tokens -> Generate Token (scope: `connections:write`) -> get `xapp-...`
2. **Bot Token**: Install to Workspace -> get `xoxb-...`
3. **Bot User ID** (required): Check the Slack App page -> Basic Information, or the bot's Slack profile (format: `U0xxxxxxx`). The @mention collaboration protocol requires each Agent to know its own and its counterpart's Bot User ID.

---

## Part 3: Collaboration Mechanism After Introduction

### Core Challenge

Two bots in the same Slack thread encounter three problems:
1. **Double response**: A human posts one message, both bots reply
2. **Loops**: Bot A replies -> Bot B gets triggered and replies -> Bot A triggered again -> infinity
3. **No routing**: No mechanism to determine "who should reply, who should stay silent"

### Why Config Alone Is Not Enough

| Config Option | Expected | Actual (source code verified) |
|---|---|---|
| `requireMention: true` | Only respond to explicit @mentions in thread | Once a bot has participated in a thread, `implicitMention` is permanently true, bypassing requireMention |
| `allowBots: "mentions"` | Only process bot messages that explicitly @mention this bot | Slack provider only does truthy/falsy check; `"mentions"` equals `true` (only Discord supports this properly) |

### Solution: Two-Layer Defense

| Layer | Mechanism | Scope | Type |
|-------|-----------|-------|------|
| Config | `requireMention: true` | Channel root messages (not threads) | Hard constraint |
| Prompt | Explicit @mention protocol | All messages within threads | Soft constraint (instruction following) |

### Explicit @mention Protocol

Each Agent participating in Discussion Mode should have the following in its workspace files:

```markdown
## Multi-Agent Thread Collaboration Rules

When in a Slack thread where other bots are also present:

1. **On receiving a message**: Check the message text for `<@YourBotID>`.
   If NOT present -> respond with ONLY `NO_REPLY`.

2. **On sending a message**: `<@TargetBotID>` explicitly mention the target.
   No @mention = conversation end signal.

3. **Roles**:
   - Orchestrator: choose @Worker / @Human / nobody (end)
   - Worker: every reply must @mention the Orchestrator

4. **Termination**: After saying "done", stop unless re-@mentioned.

5. **Round limit**: Max N rounds per thread (recommended 5-8). After that, pause and summarize to the human.
```

### Collaboration Flow

```
Human -> @Orchestrator: "Discuss X"

Phase 0 (expand spec):
  Orchestrator -> Thread: DISCUSSION SPEC (goals + acceptance criteria + termination conditions)
  Orchestrator -> @Worker: first question

Round 1/M:
  Worker -> @Orchestrator: reply (summary in thread, detailed work in files)
  Orchestrator evaluates -> continue / terminate

Termination (one of three):
  Criteria met -> DISCUSSION_CLOSE
  Max rounds reached -> ask human to intervene
  No progress for 2 consecutive rounds -> ask human to intervene
```

### Termination Protocol

```
DISCUSSION_CLOSE
Topic: <topic>
Consensus: <consensus / "No consensus reached, reason: ...">
Actions: <follow-up tasks>
Rounds Used: N/M
```

### Known Limitations

1. **Input tokens still consumed** -- messages are delivered to all bots; NO_REPLY does not prevent input token consumption
2. **Prompts are soft constraints** -- LLMs may occasionally violate rules
3. **`allowBots: "mentions"` is Discord-only** -- Slack cannot filter bot messages at the config layer
4. **`requireMention: true` is bypassed in threads** -- OpenClaw would need a `thread.requireExplicitMention` option for system-level enforcement

---

## Platform Capability Comparison

| Capability | Slack | Discord | Feishu |
|------------|-------|---------|--------|
| Delegation (sessions_send) | ✅ | ✅ | ✅ |
| Discussion (cross-bot dialogue) | ✅ Verified | ❌ (OpenClaw bug) | ❌ (Platform limitation) |
| `allowBots: "mentions"` | ❌ | ✅ | N/A |
| Multi-Account | ✅ | ✅ | ✅ |
