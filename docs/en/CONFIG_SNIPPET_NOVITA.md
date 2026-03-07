[中文](../CONFIG_SNIPPET_NOVITA.md) | **English**

> 📖 [README](../../README.en.md) → [Getting Started](../GETTING_STARTED.md) → **Novita LLM Provider Configuration**

# OpenClaw — Novita LLM Provider Configuration (Optional)

> Suitable for: Users who wish to use Novita as an LLM provider in OpenCrew.
>
> Principle:
> - Only takes effect when `NOVITA_API_KEY` is provided.
> - Uses OpenAI-compatible mode.

---

## Prerequisites

- `NOVITA_API_KEY`: Your Novita API Key (obtained from [Novita AI](https://novita.ai/)).

It is recommended to add it to `~/.openclaw/.env`:

```bash
echo 'NOVITA_API_KEY=your_NOVITA_API_KEY' >> ~/.openclaw/.env
```

---

## Incremental Configuration for `~/.openclaw/openclaw.json`

### A) Add LLM Provider (`models.providers`)

Merge the following snippet into your existing `models.providers` section:

```json
{
  "models": {
    "providers": {
      "novita": {
        "kind": "openai",
        "baseUrl": "https://api.novita.ai/openai",
        "apiKey": "${NOVITA_API_KEY}"
      }
    }
  }
}
```

---

## Post-Application: Restart + Verify

```bash
openclaw gateway restart
openclaw status
```

> Note: If `NOVITA_API_KEY` is not set, the Novita provider may fail to initialize, but it will not interfere with your existing providers' behavior.
