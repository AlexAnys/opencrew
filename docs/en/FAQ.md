[中文](../FAQ.md) | **English**

> [README](../../README.en.md) > [Getting Started](GETTING_STARTED.md) > [Core Concepts](CONCEPTS.md) > **FAQ**

# Frequently Asked Questions

---

## Basics

### What is OpenCrew?

OpenCrew is a multi-agent collaboration framework built on OpenClaw. It turns your OpenClaw from "one AI assistant" into "an AI team" -- multiple Agents, each with their own expertise, collaborating through Slack, with experience automatically distilled and retained. As the decision-maker, you only need to set direction and review results.

### Do I need to know how to code?

No. OpenCrew was designed and deployed by a non-technical user with an economics/MBA background. All you need is the ability to copy-paste commands in a terminal -- or even simpler, send the deployment instructions to your existing OpenClaw and let it handle everything for you.

### How is OpenCrew different from CrewAI / AutoGen / LangGraph?

Those are orchestration SDKs built for developers -- you write Python code to define Agents and workflows. OpenCrew is a management system built for decision-makers -- you manage an AI team through Slack without writing a single line of code.

Put simply: CrewAI solves "how to orchestrate Agents with code." OpenCrew solves "how to manage an AI team."

### Why build on OpenClaw?

OpenClaw provides powerful single-Agent capabilities (tool calling, long-term memory, multi-platform integration). OpenCrew builds on that foundation to solve the ceiling of single-Agent architecture -- context bloat, experience that doesn't stick, and difficulty running multiple tasks in parallel.

---

## Architecture

### What's the minimum number of Agents?

Three: CoS (Chief of Staff) + CTO (Technical Partner) + Builder (Executor). This is the minimum viable configuration.

Recommended additions as you grow:
- **KO** -- When you notice "we keep hitting the same pitfalls" and lessons are being lost
- **Ops** -- When you notice Agent behavior slowly drifting, becoming less reliable than before
- **CIO** -- When you need a dedicated domain expert (investing, legal, marketing, etc.)

### Aren't 7 Agents too many?

Seven is the current sweet spot. Three is too few (context still bloats). Ten is too many (coordination cost explodes: 10 Agents means 45 potential communication channels). Start with 3 and add as needed.

### Is CoS the entry point for all tasks? Does everything have to go through it?

No. CoS is not a gateway -- if you want to talk to someone, just go to their channel directly. CoS's value lies in "deep intent alignment" and "pushing things forward when you're away," not acting as an information relay.

### Why Slack instead of Discord / Feishu / WeChat?

Slack's product features naturally fit multi-Agent collaboration: threads provide task-level isolation, unreads become a to-do list, channels map to roles, and the mobile experience is excellent. OpenClaw also natively supports Slack integration.

Other platforms are on the roadmap, but we need to find an equivalent "channel + thread" mapping for each one.

---

## Usage

### Will token consumption be high?

Higher than a single Agent, because each Agent maintains its own context. But two factors keep actual cost down:

1. **Domain isolation**: Each Agent only sees information in its own domain, making per-conversation context shorter
2. **Closeout compression**: Experience is passed along as 10-15 line structured summaries (~25x compression), rather than making downstream Agents read entire conversations

### Is the Slack free plan enough?

Yes. OpenCrew uses the Socket Mode API, which is fully available on the free plan. The 90-day message history limit doesn't matter -- important information has already been distilled into Closeouts and the knowledge base.

### Is Agent-to-Agent collaboration instant?

It depends on OpenClaw's response speed -- typically a few seconds to a few tens of seconds per A2A trigger. But long tasks may span hours or even days -- that's where the Checkpoint mechanism helps you track progress.

### What if an Agent "goes off the rails"?

This is exactly why Ops exists. Ops audits all Agent self-modifications (Self-Updates) and flags anomalies with rollback recommendations. If you haven't deployed Ops yet, you can manually check whether each Agent's SOUL.md has been unexpectedly modified.

---

## Deployment

### How long does deployment take?

If Slack is already connected to OpenClaw: about 10 minutes.
If Slack is not yet connected: about 30-40 minutes (mostly spent creating the Slack App and configuring tokens).

Detailed steps: [Getting Started Guide](GETTING_STARTED.md)

### Will deployment affect my existing OpenClaw?

No. OpenCrew uses incremental deployment -- it only adds new Agents, workspaces, and configuration entries. It does not modify your existing setup. `openclaw.json` is backed up before deployment, so you can roll back at any time.

### Can I deploy on a remote server?

Yes. As long as the server can run OpenClaw and connect to the Slack API (outbound network required), you can deploy there. Run the deployment commands via SSH, or let your OpenClaw agent handle it remotely.

---

## Knowledge System

### How is a Closeout different from a regular chat summary?

A Closeout is mandatory and structured. It follows a fixed template (what was done, decisions, pitfalls, Signal score), ensuring critical information isn't lost. A regular summary is ad-hoc and easily misses key details.

### Agents score their own Signal -- is that reliable?

For now, yes. But through Ops audits and KO's secondary filtering, inaccurate scores get corrected. Over time, Signal scoring accuracy calibrates as the system is used.

### How good is cross-session knowledge retrieval?

This is the main current limitation. v1 relies on Closeouts + manual KO distillation, with no cross-session semantic search. This area is actively being explored -- contributions are welcome.

---

> [README](../../README.en.md) | [Getting Started](GETTING_STARTED.md) | [Core Concepts](CONCEPTS.md) | [Architecture](ARCHITECTURE.md)
