[中文](../FEISHU_SETUP.md) | **English**

> 📖 [README](../../README.en.md) → [Getting Started](GETTING_STARTED.md) → **Feishu Setup**

# Feishu Setup

> Goal: Connect OpenClaw with **a single Feishu custom app**, then use a "group chat = role" binding for each Agent. Adding or removing Agents later is just a matter of adding/removing group chats and updating bindings.

OpenCrew uses the Feishu **WebSocket long connection** by default -- no public server required.

> Lark (international version) users: see [Lark Section](#lark-international-version-users).

### Key difference from Slack: Thread support

OpenCrew's core model on Slack is "channel = role, thread = task" -- each task runs independently in its own thread with no cross-talk.

Feishu does have a native "Topics" (话题) feature, but **OpenClaw's Feishu plugin does not currently support thread isolation**. This means:

- **"Group chat = role" works perfectly** -- each group binds to one Agent, message routing works as expected
- **"Thread = task" is not available** -- all conversations within a group are flat; you cannot isolate different tasks into separate threads
- Practical impact: when an Agent handles multiple tasks concurrently, conversations will intermingle. For light use (one task at a time) this is fine; for heavy parallel workflows it is a noticeable limitation

> This is a known limitation of the OpenClaw Feishu plugin ([Issue #10242](https://github.com/openclaw/openclaw/issues/10242)), not the Feishu platform itself. Future plugin updates may resolve this.

---

## What you will have when you are done

After completing these steps you will have:
- One Feishu custom app (with a bot)
- Two credentials:
  - **App ID**: `cli_xxxxxxxxx`
  - **App Secret** (keep this safe -- do not share)
- OpenClaw connected to Feishu, with the bot added to every group chat you want to use

---

## Step 1: Create a Feishu app and enable bot capability (~10 min)

1. Go to [Feishu Open Platform](https://open.feishu.cn/app) and log in with your Feishu account
2. Click **Create Custom App** (do not select "Custom Bot" -- that is webhook-only with limited functionality)
3. Enter an app name (e.g. "OpenCrew Assistant") and description, choose an icon
4. Inside the app, go to **Add Capabilities** in the left sidebar → find **Bot** → click **Add**
5. Set a bot name and save

> We recommend creating the app with a Feishu **admin account** -- admin-created apps are auto-approved on publish, no waiting required.

---

## Step 2: Configure permissions and event subscriptions

### 2a. Batch-import permissions

Left sidebar → **Permission Management** → click **Batch Import** → paste the following JSON:

```json
{
  "scopes": {
    "tenant": [
      "im:chat",
      "im:chat.members:bot_access",
      "im:message",
      "im:message.group_at_msg:readonly",
      "im:message.group_msg",
      "im:message.p2p_msg:readonly",
      "im:message:readonly",
      "im:message:send_as_bot",
      "im:resource",
      "contact:user.employee_id:readonly"
    ],
    "user": [
      "im:chat.access_event.bot_p2p_chat:read"
    ]
  }
}
```

> Existing permissions are automatically skipped. For advanced features (images, files, documents), see the [openclaw-feishu full permission list](https://github.com/AlexAnys/openclaw-feishu).

### 2b. Configure event subscriptions

Left sidebar → **Events & Callbacks** → **Event Configuration**:

1. Subscription method: select **Use long connection to receive events** (this is key -- no public server needed)
2. Click **Add Event**, search for and add: `im.message.receive_v1` (receive messages)

---

## Step 3: Copy credentials and publish the app

### 3a. Copy credentials

Left sidebar → **Credentials & Basic Info**, copy:
- **App ID** (format: `cli_xxxxxxxxx`)
- **App Secret**

### 3b. Publish

Left sidebar → **Version Management & Release** → **Create Version** → enter release notes → **Submit**

- Admin-created apps: auto-approved, takes effect in seconds
- Non-admin-created apps: requires admin approval in Feishu Workbench → App Management

---

## Step 4: Connect Feishu to OpenClaw

Run in your terminal:

```bash
openclaw channels add --channel feishu \
  --app-id "cli_xxxxxxxxx" \
  --app-secret "your_app_secret"
```

> You can also use the interactive method: `openclaw channels add`, select Feishu, and paste credentials when prompted.

Then restart the gateway:

```bash
openclaw gateway restart
```

Verify that Feishu is online:

```bash
openclaw channels status --probe
# or
openclaw status
```

You should see `feishu ws connected` or `feishu provider ready` in the logs.

---

## Step 5: Create OpenCrew group chats and add the bot

**Minimum setup (3 group chats, recommended starting point):**
- HQ group (CoS -- Chief of Staff)
- Tech group (CTO -- Tech Partner)
- Build group (Builder -- Executor)

**Optional extras:**
- Invest group (CIO -- Domain Expert)
- Knowledge group (KO -- Knowledge Officer)
- Ops group (Ops -- Governance)
- Research group (Research -- On-demand)

In each group chat: tap the group settings icon → **Add Bot** → search for your bot name → Add.

---

## Step 6: Get group chat IDs (two methods)

### Method A: Use OpenClaw to resolve

```bash
openclaw channels resolve --channel feishu "HQ group" --json
```

### Method B: Check the logs

```bash
openclaw logs --follow
```

Send a message mentioning the bot in a group chat. The logs will show the `chat_id` (format: `oc_xxxxxxxxxxxxxxxx`) -- that is the group chat ID.

---

## FAQ

### No message input box?

Event subscriptions are not configured. Go to Feishu Open Platform → your app → Events & Callbacks → add `im.message.receive_v1` → select "long connection" → create a new version → publish.

### Bot not responding at all?

Check in order:
1. **Is the gateway running?** `openclaw gateway status`
2. **Is the app published?** Check Version Management for a published version
3. **Are event subscriptions configured?** Confirm "long connection" is selected and `im.message.receive_v1` is added
4. **Are permissions sufficient?** At minimum: `im:message`, `im:message.p2p_msg:readonly`, `im:message:send_as_bot`
5. **Check logs**: `openclaw logs --follow` and send a message

### Bot not responding in group chats?

By default, the bot only responds when @mentioned. Make sure the bot has been added to the group chat.

### Got a pairing code?

On first contact, the bot replies with a pairing code for security. Run:

```bash
openclaw pairing approve feishu <pairing_code>
```

This is a one-time operation.

### App approval rejected?

Have a Feishu admin create the app (admin-created apps are auto-approved), or ask the admin to approve manually in Workbench → App Management.

---

## Advanced: Separate Bot per Agent (Multi-App Mode)

> The default "single bot" mode works for most scenarios. Consider multi-app mode only when:
> - You want each Agent to have its own name and avatar (visually distinct in group chats)
> - You need independent API rate-limit quotas (Feishu bills per app)
> - You need permission isolation (different Agents accessing different data scopes)

### Single Bot vs Multi-Bot comparison

| Dimension | Single Bot (default) | Multi-Bot (advanced) |
|-----------|---------------------|---------------------|
| Config complexity | Low (1 app) | Medium (1 app per Agent) |
| Agent appearance | Shared name & avatar | Independent identity |
| API quota | Shared | Independent (N x capacity) |
| Permission isolation | Shared | Independent |
| Best for | Quick start | Production environments |

### How to configure

1. **Create a separate app for each Agent** -- follow the same [Step 1](#step-1-create-a-feishu-app-and-enable-bot-capability-10-min) ~ [Step 3](#step-3-copy-credentials-and-publish-the-app) for each app
2. **Use the OpenClaw `accounts` multi-account format:**

```yaml
channels:
  feishu:
    domain: feishu
    connectionMode: websocket
    accounts:
      cos-bot:
        name: "CoS Chief of Staff"
        appId: "cli_cos_xxxxx"
        appSecret: "your-cos-secret"
        enabled: true
      cto-bot:
        name: "CTO Tech Partner"
        appId: "cli_cto_xxxxx"
        appSecret: "your-cto-secret"
        enabled: true
```

3. **Use `accountId` in Agent bindings to map each Agent to its Bot:**

```yaml
agents:
  - name: cos
    bindings:
      - channel: feishu
        accountId: cos-bot
        peer:
          kind: group
          id: "oc_xxx"
```

### Notes

- Each app needs its own event subscriptions (`im.message.receive_v1`) and permissions (see [Step 2](#step-2-configure-permissions-and-event-subscriptions))
- In "one group per Agent" mode, add only the corresponding bot to each group to avoid duplicate messages
- A2A communication is unaffected -- it goes through OpenClaw's internal `sessions_send`, independent of bot count

---

## Lark (international version) users

The Lark console does not support WebSocket long connections. You need **Webhook mode** with a public tunnel.

For the full Lark setup tutorial, see the [openclaw-feishu Lark guide](https://github.com/AlexAnys/openclaw-feishu#-lark国际版接入指南).

Key differences:
- Developer console: [open.larksuite.com](https://open.larksuite.com) (not open.feishu.cn)
- Connection method: Webhook HTTP callback (requires a public URL -- Cloudflare Tunnel recommended)
- Config requires `domain: "lark"` and `connectionMode: "webhook"`

---

## Reference

- [Feishu Open Platform docs](https://open.feishu.cn/document)
- [OpenClaw Feishu integration docs](https://docs.openclaw.ai/channels/feishu)
- [openclaw-feishu: Feishu setup guide & community support](https://github.com/AlexAnys/openclaw-feishu)

---

> 📖 Next → [Getting Started](GETTING_STARTED.md) · [Feishu Config Reference](CONFIG_SNIPPET_FEISHU.md)
