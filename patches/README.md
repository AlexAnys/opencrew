# patches/（高级）

这里放的是一些 **高级 workaround / 思路验证**。

> 开源默认路径：**不依赖 patches**。请先用 thread 工作法（见 `docs/KNOWN_ISSUES.md`）。

---

## slack-thread-routing.sh（实验性 / 不保证可用）

### 想解决什么
OpenClaw 当前 Slack 路由下，同一频道的多条 root message 可能共享同一个 channel session。
我们希望做到：**每条 root message 自动变成一个独立 session**，减少上下文污染。

### 为什么这里不提供“一键 patch”
OpenClaw 的 dist 打包结构会随版本变化；一个可靠的 patch 需要：
- 精确定位目标文件（版本检测）
- 可验证的 patch 是否生效
- 明确回滚

当前脚本更多是“备份 + 指南骨架”。如果你能提供稳定可复现的实现，欢迎 PR。

### 风险
- dist-level patch 会被 OpenClaw 升级覆盖
- 可能导致不可预期行为

结论：**不推荐新手使用。**
