[中文](../JOURNEY.md) | **English**

# Development Journey — From One Person's Pain Points to a Virtual Team

> This project grew out of real-world practice by a heavy OpenCrew user: starting from personal pain points, iterating through trial and error in real workflows. Here's the development journey and the lessons learned along the way.

## Why build this

After using OpenCrew for a few months, I hit a core contradiction: **OpenCrew's capability ceiling is high, but the single-agent architecture hits a usability wall.**

Specifically:
- Context built up during dev project A became noise when switching to financial task B
- Cognitive overhead from switching between sessions was brutal when running multiple projects in parallel
- Valuable experience (pitfalls hit, decisions made) was scattered across chat logs with no way to systematically reuse it
- The agent needed my confirmation at every step, but honestly, for many of those decisions I wasn't more qualified than it was

Core insight: **The problem isn't that OpenCrew isn't powerful enough. It's that one agent isn't enough.** You need a team.

## Phase 1: Role design (from 3 to 7)

Initially I imagined just 3 roles: CoS (Chief of Staff), CTO (technical lead), Builder (executor).

Quickly discovered that wasn't enough:
- Nobody was responsible for knowledge distillation, so lessons learned were quickly forgotten
- Nobody audited system rule changes, so agent behavior was slowly drifting
- Investment-related tasks were mixed in with development tasks

So I expanded to 7: added KO (Knowledge Officer), Ops (Governance), CIO (Investment/Domain), and Research.

**Lesson**: The sweet spot for role count depends on your actual diversity of needs. 3 is too few (context still bloats), 10 is too many (coordination cost explodes). Start with the core 3 and add as needed.

## Phase 2: Collaboration mechanics (A2A two-step trigger)

The biggest technical challenge was getting agents to collaborate.

**Gotcha 1: Bot message self-loop**

I initially assumed that when Agent A posted a message in Slack, Agent B would automatically pick it up. Turns out, in OpenCrew's Slack integration, messages sent by the bot are ignored by itself -- because all agents share a single bot identity.

**Solution: Two-step trigger**
1. Slack message (the visible anchor humans can see)
2. `sessions_send` (the actual execution trigger)

**Gotcha 2: deliveryContext drift**

After sessions_send fired, the target agent sometimes didn't reply in the Slack thread but instead responded in the webchat context. Investigation revealed that the sessionKey construction method affects deliveryContext.

**Solution: Visibility contract**

Validate the sessionKey before sending. Check the thread's latest_reply after sending. No reply? Mark it `failed-delivery`.

**Gotcha 3: A2A loop storm**

Early on I hadn't set `maxPingPongTurns`. Two agents triggering each other caused a message storm and token explosion.

**Solution**: `maxPingPongTurns = 4` + only allow CoS/CTO/Ops to initiate A2A.

## Phase 3: Information flow and knowledge distillation

**Core problem**: Agents did a lot of work, but experience wasn't accumulating.

**v1 approach: Mandatory Closeout**

Every A/P/S task must produce a 10-15 line structured summary. It includes: what was done, what decisions were made, what pitfalls were hit, signal score.

**Result**: Information compression ratio of roughly 25x. A 50k token session produces a Closeout of only 1-2k.

**v2 approach: Signal score filtering**

Not every Closeout is worth feeding into the knowledge base. A 0-3 signal score filters them:
- 0-1: Agent keeps it locally, doesn't propagate
- 2-3: Goes to #know, KO extracts insights

## Phase 4: Governance and self-evolution

**Problem**: Agents can modify their own SOUL.md and MEMORY.md, but without auditing, behavior slowly drifts.

**Solution**:
- Self-Update Template: Every self-modification must record motivation, changes, and rollback method
- Ops Review: Five-dimension audit for S-class changes
- `#ops requireMention = true`: Reduces noise in the Ops channel

## Key takeaways

### Design layer
- **Splitting role files matters**: Separate SOUL (who you are) from AGENTS (how you work) to prevent process details from diluting role identity
- **SOUL.md must be read first**: It's the highest-priority context
- **Shared protocols should be few and precise**: Too many and nobody reads them, too few and there's no constraint. 9 files is the current version; v2 is exploring compression down to 3

### Technical layer
- **Config-level hard constraints > doc-level soft constraints**: `allowAgents`, `maxPingPongTurns`, `requireMention` -- these are what actually enforce behavior
- **Thread isolation is fundamental**: `historyScope = "thread"` is the foundation the entire system runs on
- **A2A is the most fragile link**: The deliveryContext drift issue still doesn't have a root-cause fix

### Operations layer
- **Start simple**: Get the CoS -> CTO -> Builder pipeline working first, then add KO/Ops
- **Trust but verify**: Give agents autonomy, but maintain visibility through Closeouts and audits
- **Perfect is the enemy of iteration**: This system isn't perfect, but it's already solving real problems

## Advice for new users

1. **Deploy 3 agents first** (CoS + CTO + Builder) and get the basic flow working
2. **Talk to CoS in #hq**, let it dispatch tasks to CTO for you
3. **Watch the Slack threads** to confirm A2A is working
4. **Add KO/Ops as needed** -- when you notice experience slipping away or system behavior drifting
5. **Document your own pitfalls** -- these will eventually become your knowledge assets

## Why open source

I originally wanted to wait until all optimizations were done before releasing. But I realized:
- Reaching the ideal standard was still too far away (one person's capacity is limited)
- The current version already solves the core pain points
- Continuously debugging and integrating across multiple architectural directions is nearly impossible solo
- I wanted to find like-minded people to push this forward together

So I chose the "ship when usable, iterate while using" strategy. If you've hit the same pain points, you're welcome to join.
