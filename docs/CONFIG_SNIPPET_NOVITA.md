**中文** | [English](en/CONFIG_SNIPPET_NOVITA.md)

> 📖 [README](../README.md) → [完整上手指南](GETTING_STARTED.md) → **Novita LLM Provider 配置**

# OpenClaw — Novita LLM Provider 增量配置 (可选)

> 适用：希望在 OpenCrew 中使用 Novita 作为 LLM Provider 的用户。
>
> 原则：
> - 仅在提供 `NOVITA_API_KEY` 时生效。
> - 使用 OpenAI 兼容模式。

---

## 你需要准备的占位符

- `NOVITA_API_KEY`：你的 Novita API Key（从 [Novita AI 官网](https://novita.ai/) 获取）。

建议将其写入 `~/.openclaw/.env`：

```bash
echo 'NOVITA_API_KEY=你的_NOVITA_API_KEY' >> ~/.openclaw/.env
```

---

## 需要加到 `~/.openclaw/openclaw.json` 的增量

### A) 新增 LLM Provider (`models.providers`)

把这段配置合并到你现有的 `models.providers` 里：

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

## 应用后：重启 + 验证

```bash
openclaw gateway restart
openclaw status
```

> 注意：如果 `NOVITA_API_KEY` 未设置，Novita provider 可能无法正常初始化，但不会影响你原有的 provider 行为。
