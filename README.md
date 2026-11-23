# Deploy and Host Rakazo on Railway

Rakazo is an open-source, self-hosted platform for persistent AI teammates. Each bot keeps its own memory, routines, apps, and sandboxed computer, and works from the web, desktop, or mobile clients. Connect your own model provider and keep credentials and data on infrastructure you control.

## About Hosting Rakazo

Hosting Rakazo on Railway runs the API, background worker, and web client in one service backed by Railway-managed PostgreSQL. A persistent volume keeps bot workspaces, uploads, and artifacts across redeploys. Bot computers run in a separate, empty Railway environment created by the service, so sandbox workloads cannot reach the application's private database network. The first start applies database migrations, provisions a restricted runtime database role, and creates the initial owner account. Railway supplies HTTPS and the public domain, while the API stays on loopback behind the web proxy. No Docker host or third-party sandbox provider is required.

## Common Use Cases

- Run a personal AI teammate that triages email, drafts replies, files issues, and works in a browser.
- Schedule recurring routines such as daily reports, inbox summaries, and monitoring checks.
- Give several bots a shared memory and let them collaborate in group chats.
- Research and collect data with a sandboxed desktop, terminal, files, and browser.
- Replace per-task automation subscriptions with your own model keys and infrastructure.

## Dependencies for Rakazo Hosting

- Official Rakazo application image `ghcr.io/elie222/rakazo/app:v0.14.0`, extended with a process supervisor and start script.
- One Railway-managed PostgreSQL database (PostgreSQL 16 or newer) for accounts, chats, memory, and the job queue.
- One persistent volume at `/data` for bot workspaces, uploads, and local artifacts.
- A Railway workspace API token that can create environments and sandboxes in the project.
- A model provider account or key (OpenRouter, Anthropic, OpenAI, and others), connected after sign-in.
- Railway usage for the app, database, volume, and any running sandbox computers, plus model usage billed by your provider.
- Optional integrations: SMTP or Resend for email, Google or Apple OAuth, Slack, Telegram, WhatsApp, and MCP servers.

### Implementation Details

The service runs three processes: the Hono API on loopback port `3100`, the Graphile worker, and the Vite web preview on port `5173`. The start script applies migrations with the database owner, creates the restricted `rakazo_app` login used by the application, bootstraps the owner account, and then supervises all three processes; if any process exits, Railway restarts the service. Public registration is disabled on every start, and only the operator account is created. Health checks probe the web port at `/`; the start script waits for the API's `/ready` endpoint before exposing the web client. Bot computers live in a separate Railway environment named from a hash of the project, service, and application environment, and idle computers stop after ten minutes by default. Run one replica and keep service sleeping disabled, because all processes share the same volume.

## Comparison with Alternatives

✅ = built in or available directly, ❌ = not available or requires a workaround.

| Capability | This template (Rakazo) | Zapier Central / Make | Grok Bot |
| --- | --- | --- | --- |
| Hosting model | Self-hosted on Railway | Vendor cloud only | Vendor cloud only |
| Source license | Apache-2.0 | Proprietary | Proprietary |
| Billing | Railway usage plus your model provider | Per-task or per-operation subscription | Vendor subscription |
| Model choice | Your own providers or a local OpenAI-compatible server | Vendor-managed models | xAI models |
| Persistent teammate memory and routines | ✅ | ❌ (workflow data only) | ✅ |
| Sandboxed computer per bot | ✅ | ❌ | ✅ |
| Web, desktop, and mobile clients | ✅ | Web | Vendor clients |
| Credentials and data stay on your infrastructure | ✅ | ❌ | ❌ |

Rakazo is also a self-hosted alternative to OpenClaw and Hermes Agent. Those are agent runtimes and gateways; Rakazo adds a full teammate product with a per-bot computer, memory, routines, and clients for every device.

## Security Considerations

- `RAILWAY_API_TOKEN` can create environments and sandboxes. Use a dedicated workspace and the narrowest token that works; never store it in bot files, prompts, or model connection settings.
- Bot computers run in a separate Railway environment. Do not add production services, databases, or shared secrets to that environment.
- The generated owner password is visible in the service variables. Change it after the first sign-in. Changing the variable later does not reset an existing account.
- Keep `ENCRYPTION_KEY` and the database password stable across redeploys. Changing the encryption key makes stored credentials and encrypted content unreadable.
- Public registration is closed on every start. This template is intended for a personal or small-team deployment with one operator account.
- PostgreSQL is private and only the web port is published. The API listens on loopback inside the service.
- Run a single replica with sleeping disabled. Multiple replicas would run duplicate workers against one volume and the same job queue.
- Back up PostgreSQL, the `/data` volume, and `ENCRYPTION_KEY` together, and test restoring them as a set. Railway volume persistence is not a backup.
- Content encryption is on by default. Keep it enabled unless you have a specific reason to store content readable at rest.

## Why Deploy Rakazo on Railway?

Railway is a singular platform to deploy your infrastructure stack. Railway will host your infrastructure so you don't have to deal with configuration, while allowing you to vertically and horizontally scale it.

By deploying Rakazo on Railway, you are one step closer to supporting a complete full-stack application with minimal burden. Host your servers, databases, AI agents, and more on Railway.

Railway also supplies the managed PostgreSQL database, persistent storage, TLS, and the isolated sandbox environment that Rakazo uses for bot computers, so there is no Docker host to maintain and no separate sandbox service to pay for.

## License

Rakazo is licensed under the Apache License 2.0. This repository contains deployment packaging and documentation only and is not affiliated with or endorsed by the Rakazo project.
