# 小剑灵公开 AI 代理

服务：https://little-sword-spirit-api.nayoutang3.workers.dev

客户端：POST `/v1/chat/completions`，无需客户端密钥；保持原聊天响应格式。GET `/health` 检查服务是否配置。

## 密钥与边界

- `DEEPSEEK_API_KEY` 仅在 Cloudflare Secret 中。客户端不读环境密钥或 `secrets/llm_api_key.txt`，导出排除 `secrets/*`、`server/*`、`docs/*`。
- 固定上游地址和模型，客户端不能指定上游、密钥或模型。请求最多 240 KB、80 条消息、12 万字符；输出最多 1024 token；上游超时 25 秒。
- 不把上游错误原文或请求头返回客户端，不记录聊天正文、密钥或原始 IP；限额存储使用 IP 哈希。
- 这是公开游戏服务，客户端标识和上下文检查不是身份认证。限额用于控制滥用及调用总量，不能保证只被游戏客户端调用。

## 默认额度

SQLite Durable Object 全局串行事务计数，跨实例及重启共享：

- 每 IP 每 10 分钟最多 60 次。
- 每 IP 每 UTC 日最多 400 次。
- 全服务每 UTC 日最多 5000 次。

窗口为固定窗口；被上游拒绝/超时的调用仍计数，超过限额返回 429 与 Retry-After。没有可用计数服务时拒绝请求，不绕过限额。以上是请求上限，不是精确金额预算。多人共用公网 IP 时共享限额。

## 部署与检查

```powershell
node --test server/cloudflare/worker.test.mjs
npx wrangler deploy --config server/cloudflare/wrangler.json
npx wrangler secret put DEEPSEEK_API_KEY --config server/cloudflare/wrangler.json
```

通过交互输入 Secret，不将真实值放入命令、文档或版本库。修改 `wrangler.json` 中限额后重新部署生效。该服务与熙宁抉择使用独立 Worker 和限额。

真实连通性检查：

```powershell
Godot --headless --path . --script res://tools/public_proxy_smoke.gd -- --cooperation-sim --live-proxy
```

公开包额外添加 `--exported-public` 检查密钥文件不存在。所有检查禁止写入玩家存档。

## 实现依据

Cloudflare SQLite Durable Object 存储与迁移文档：
https://developers.cloudflare.com/durable-objects/api/sqlite-storage-api/
https://developers.cloudflare.com/durable-objects/reference/durable-objects-migrations/
