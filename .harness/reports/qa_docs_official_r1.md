# QA Report: Documentation Review Against Official Sources

## Overall Verdict: NEEDS-WORK

Three factual inaccuracies were found that require correction. The documentation is generally well-written and clear, but the version claims and one PR reference are verifiably wrong.

---

## 1. Discord Permission Isolation

### Accuracy vs official docs: PASS (with minor note)

The permission setup flow described in Step 5b (Create role -> server-level deny Send Messages -> per-channel Allow) is **correct** and matches Discord's documented permission hierarchy.

According to Discord's official developer documentation at [docs.discord.com/developers/topics/permissions](https://docs.discord.com/developers/topics/permissions):

1. Server-level role permissions provide the base.
2. Channel-level overrides (green check / red X / gray slash) override the server-level defaults.
3. If a role lacks "Send Messages" at the server level (not granted), and a channel override sets it to Allow (green checkmark), the bot **will** be able to send in that specific channel.

### Permission names correct: PASS

All permission names used in the docs match Discord's official names:
- "Send Messages" -- correct (API: `SEND_MESSAGES`)
- "View Channels" -- correct (API: `VIEW_CHANNEL`, UI displays as "View Channels")
- "Read Message History" -- correct (API: `READ_MESSAGE_HISTORY`)
- "Send Messages in Threads" -- correct (API: `SEND_MESSAGES_IN_THREADS`)
- "Create Public Threads" -- correct (API: `CREATE_PUBLIC_THREADS`)
- "Create Private Threads" -- correct (API: `CREATE_PRIVATE_THREADS`)
- "Manage Threads" -- correct (API: `MANAGE_THREADS`)
- "Add Reactions" -- correct (API: `ADD_REACTIONS`)
- "Mention Everyone" -- correct (API: `MENTION_EVERYONE`)
- "Manage Channels" -- correct (API: `MANAGE_CHANNELS`)

### Permission hierarchy correct: PASS

The statement "Do NOT grant Administrator -- Administrator bypasses all channel overrides" is **factually correct**. Discord's official dev docs state: "ADMINISTRATOR overrides any potential permission overwrites, so there is nothing to do here." The Administrator permission short-circuits all channel override calculations.

### Role-per-bot approach: PASS

The multi-bot setup suggesting a separate role per bot with per-channel Send Messages overrides is a valid and recommended pattern.

### Minor note on "View Channel" vs "View Channels"

Line 128 of the EN Discord doc uses "View Channel" (singular) while line 60 and 143 use "View Channels" (plural). The API flag is `VIEW_CHANNEL` (singular), but the Discord UI shows "View Channels" (plural). Both are understood, but consistency within the doc would be better.

### 50-bot limit: PASS

The claim "Discord servers allow up to 50 bots" is correct. Discord imposes a 50-bot limit on servers.

### 100-server vs 75-server threshold: MINOR INACCURACY

The EN doc (line 45) states "Bots in fewer than 100 servers do not need review." The official threshold is actually 75 servers -- the application form for Privileged Intents appears once a bot reaches 75 servers. The actual enforcement kicks in at 100 servers. The CN doc says the same ("小于 100 个服务器的 bot 无需审核"). This is a simplification that could mislead users with bots approaching 75 servers.

The Multi-Bot section (line 209 EN) correctly says "Bots in more than 75 servers require a separate Message Content Intent approval" -- this contradicts the earlier 100-server claim at line 45.

---

## 2. Feishu groupSessionScope

### Config key verified: PASS

`groupSessionScope` is a valid configuration key. The OpenClaw v2026.3.1 release notes confirm: "add configurable group session scopes (`group`, `group_sender`, `group_topic`, `group_topic_sender`)". The value `"group_topic"` is confirmed as one of the four valid options.

### Version requirement verified: FAIL -- INCORRECT VERSION

**Both EN and CN docs claim `groupSessionScope` requires "OpenClaw >= 2026.2". This is wrong.**

Evidence:
- OpenClaw v2026.3.1 release notes (https://github.com/openclaw/openclaw/releases/tag/v2026.3.1) explicitly list "Feishu/Group session routing: add configurable group session scopes" as a new feature.
- The feature is also referenced in Issue #29791 (opened Feb 28, 2026, closed via PR #29788, merged March 2, 2026) -- well after the 2026.2 release.
- The official Feishu channel docs at docs.openclaw.ai/channels/feishu do NOT mention `groupSessionScope` by name, suggesting it may be documented under a different naming convention or is very recent.

**Correct version**: OpenClaw >= 2026.3.1

This error appears in 4 locations:
- `docs/en/FEISHU_SETUP.md` line 25: heading says "OpenClaw >= 2026.2"
- `docs/FEISHU_SETUP.md` line 25: heading says "OpenClaw >= 2026.2"
- `docs/en/KNOWN_ISSUES.md` line 74 and 82: says "OpenClaw >= 2026.2"
- `docs/KNOWN_ISSUES.md` line 67 and 75: says "OpenClaw >= 2026.2"

### YAML config example syntax: PASS

The YAML example is syntactically correct. The structure with `channels.feishu.groupSessionScope: "group_topic"` alongside `domain`, `connectionMode`, `appId`, `appSecret` is properly formatted.

### SecretRef bug (Issue #47436): PASS

- The issue exists and is OPEN: "[Bug] Feishu multi-account (accounts.*) appSecret SecretRef fails to resolve, crashes feishu plugin after ~3 minutes"
- It confirms that SecretRef in multi-account Feishu mode causes the plugin to crash after ~3 minutes, taking down the primary bot as well.
- The workaround described in the docs ("use plaintext secrets" or "restart the gateway twice") is a reasonable approximation, though the issue itself does not explicitly state "restart twice" as a workaround -- a fix PR (#47652) has been submitted with per-account error isolation.
- The docs' description of the bug is substantively accurate.

### Issue #10242 reference: PARTIALLY INACCURATE

The docs reference Issue #10242 as evidence of the group chat thread isolation limitation. However, Issue #10242 is actually titled "[Feature Request] Restore 'New Thread' capability for Feishu (Lark) Channel in **DMs**" -- it is about DM thread capability, not group chat session isolation. While the broader point about Feishu lacking thread isolation is valid, this specific issue is not the right citation. Issue #29791 ("[Feature]: Support thread-based replies in Feishu plugin") would be a more accurate reference for the group chat topic.

---

## 3. Deployment Order

### Logical correctness: PASS

The 9-step deployment order is logically sound:
1. Create bot/app on platform
2. Configure permissions/intents
3. Invite bot to server/workspace/groups
4. Create agent channels/groups
5. Connect platform to OpenClaw (`openclaw channels add`)
6. Deploy OpenCrew files (shared protocols + workspaces)
7. Write OpenClaw config (agent bindings, channel IDs)
8. Restart gateway
9. Verify

This order correctly places platform-side setup (steps 1-4) before OpenClaw-side configuration (steps 5-8), which is necessary because `openclaw channels add` requires bot tokens that only exist after step 1.

### Matches OpenClaw workflow: PASS

You cannot run `openclaw channels add` without a bot token (Discord) or app credentials (Feishu), so the platform setup must come first. The deployment order correctly captures this dependency.

### Common Mistakes section: PASS

All 5 common mistakes are realistic and would genuinely be encountered by new users:
1. Wrong deployment order -- logical error new users would make
2. Skipping channel permission isolation -- addresses Issue #34
3. Forgetting to restart gateway -- a standard "gotcha"
4. Channel ID mismatch -- common copy-paste error
5. Bot not invited to channels -- frequently missed step

### PR #3672 reference: FAIL -- PR WAS NOT MERGED

Both EN and CN Discord docs (line 210/211) state: "OpenClaw multi-account support was introduced in [PR #3672](https://github.com/openclaw/openclaw/pull/3672) (merged January 2026)."

**This is factually incorrect.** PR #3672 was **CLOSED without merging** on 2026-02-01 (`mergedAt: null`, `mergeCommit: null`, `state: CLOSED`). The PR itself references `moltbot/moltbot` in its "Fixes" line, suggesting it predates a repo rename. Multi-account Discord support does exist in current OpenClaw versions (as evidenced by multiple issues referencing it), but it was NOT delivered via PR #3672. The correct PR that shipped this feature needs to be identified, or the reference should be removed.

---

## 4. Known Issues Update

### Factual accuracy: PASS (with version caveat)

The Feishu P1 entry accurately describes:
- The symptom: "all conversations within a single group are flat -- there is no thread-level session isolation"
- The resolution: `groupSessionScope: "group_topic"` enabling per-topic session isolation
- The distinction between built-in and community plugins

However, the version requirement "OpenClaw >= 2026.2" is incorrect (should be >= 2026.3.1), as noted in Section 2.

### Link integrity: PASS (with style note)

- CN KNOWN_ISSUES.md links to `FEISHU_SETUP.md#更新groupsessionscopeopenclaw--20262` -- this anchor matches the CN heading and will resolve correctly on GitHub.
- EN KNOWN_ISSUES.md links to `../en/FEISHU_SETUP.md#update-groupsessionscope-openclaw--20262` -- this anchor matches the EN heading and will resolve correctly. However, since both files are in `docs/en/`, the `../en/` prefix is unnecessarily verbose. `FEISHU_SETUP.md#update-groupsessionscope-openclaw--20262` would be cleaner and less fragile.

---

## 5. Cross-file Consistency

### EN/CN match: PASS

- Discord permission names are consistent across EN and CN. The EN version uses the English Discord permission names ("Send Messages", "View Channels", etc.), while the CN version uses the same English names in the tables (appropriate since Discord's UI is in English) with Chinese descriptions.
- Feishu config keys (`groupSessionScope`, `appId`, `appSecret`, `connectionMode`, `accounts`) are identical in both EN and CN versions.
- The YAML config examples are structurally identical between EN and CN, differing only in placeholder values for appSecret (EN: "your_app_secret", CN: "你的AppSecret").

### Org name consistency: PASS

No references to the wrong org name `open-claw/open-claw` were found anywhere in the docs directory. All references use the correct `openclaw/openclaw` format.

### Broken links: NO BROKEN LINKS DETECTED

All internal markdown links have matching anchors in the target files. External links to GitHub issues (#10242, #47436, #3306) and PRs (#3672) are valid URLs (though #3672 is closed/not-merged and #10242 is not the ideal reference, the links themselves work).

---

## 6. Beginner Readability

### Clarity assessment: GOOD

The documentation is well-structured and would be followable by a beginner:
- Step numbering is clear and sequential
- Each step includes specific UI navigation paths (e.g., "Server Settings -> Roles -> Create Role")
- Warning/important callouts are used appropriately to flag critical steps
- Time estimates are helpful for setting expectations
- The "What you will have when you are done" sections provide clear success criteria

### Missing steps: MINOR GAP

In the Discord Step 5b, the docs say "Do NOT grant Send Messages at the server level" but do not explicitly say what to do if the bot already has Send Messages from the invite (Step 3). Since Step 3's permission table includes "Send Messages", a beginner might be confused about why they granted it in Step 3 only to revoke it in Step 5b. A clarifying note such as "The permissions you selected in Step 3 set the OAuth2 invite scope, but the role-based permissions in Step 5b take precedence for channel-level control" would help.

### Confusing sections: MINOR

The Feishu docs mention both "OpenClaw >= 2026.2" and reference features that actually require 2026.3.1. A beginner running OpenClaw 2026.2.x would follow these instructions, find that `groupSessionScope` does not work, and be stuck without understanding why.

---

## Must-Fix Issues

1. **INCORRECT VERSION**: Change `groupSessionScope` version requirement from "OpenClaw >= 2026.2" to "OpenClaw >= 2026.3.1" in all 4 files (EN/CN FEISHU_SETUP.md and EN/CN KNOWN_ISSUES.md). The feature was introduced in the v2026.3.1 release, as confirmed by the official release notes.

2. **PR #3672 NOT MERGED**: Remove or correct the claim that "PR #3672 (merged January 2026)" introduced multi-account Discord support. PR #3672 was closed without merging (`mergedAt: null`). Either find the correct PR that shipped this feature, or remove the PR reference and simply state that multi-account support is available in current OpenClaw versions.

3. **ISSUE #10242 MISCHARACTERIZED**: Issue #10242 is about DM thread capability, not group chat session isolation. Consider replacing the reference with Issue #29791 ("[Feature]: Support thread-based replies in Feishu plugin") which more accurately describes the group chat thread isolation problem, or add both references with proper context.

## Recommendations

1. **Reconcile 100-server vs 75-server threshold**: Line 45 of both EN/CN Discord docs says "fewer than 100 servers" while the Multi-Bot section correctly says "more than 75 servers." Discord's actual threshold for Privileged Intent application is 75 servers. Recommend updating line 45 to say "fewer than 75 servers" for consistency.

2. **Normalize "View Channel" vs "View Channels"**: Line 128 of EN DISCORD_SETUP.md uses "View Channel" (singular) while lines 60 and 143 use "View Channels" (plural). Pick one and be consistent (recommend "View Channels" to match the Discord UI).

3. **Simplify EN KNOWN_ISSUES link path**: Change `../en/FEISHU_SETUP.md#update-groupsessionscope-openclaw--20262` to `FEISHU_SETUP.md#update-groupsessionscope-openclaw--20262` since both files are in the same `docs/en/` directory.

4. **Add clarifying note between Step 3 and Step 5b in Discord docs**: Explain the relationship between OAuth2 invite permissions (Step 3) and role-based channel permissions (Step 5b) to avoid beginner confusion.

5. **SecretRef workaround accuracy**: The "restart the gateway twice" workaround is not explicitly documented in Issue #47436. Consider softening to "restart the gateway after credential changes; a fix is tracked in Issue #47436" or referencing PR #47652 which implements per-account error isolation.

---

*Report generated: 2026-03-27*
*Verification method: Web search, official Discord developer docs, OpenClaw GitHub releases/issues/PRs via gh CLI, DeepWiki*
