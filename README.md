# Seekmodo Ruby SDK

Shared Ruby SDK for building [Seekmodo](https://seekmodo.com) storefront connectors, admin automation, and MCP agents. The gem ships four clients behind one namespace (`Seekmodo::Sdk`):

| Client | Auth | Base URL | Use when |
|--------|------|----------|----------|
| `Connector::Client` | HMAC (`tenant_id` + `shared_secret`) | `https://mcp.seekmodo.com` | Server-side connector: index catalog, batch events, handshake, mint browser tokens |
| `Storefront::Client` | JWT Bearer (`get_token` callback) | `https://gateway.seekmodo.com` | Storefront widgets, headless apps, anything that runs in the browser or on a token-minting server |
| `Admin::Client` | `X-Seekmodo-Admin-Key` | `https://mcp.seekmodo.com` | Operator/admin automation: synonyms, pins, LTR, analytics |
| `Mcp::Client` | HMAC **or** operator bearer | `https://mcp.seekmodo.com/mcp` | JSON-RPC MCP (`initialize`, `tools/list`, `tools/call`) for AI agents |

**Status**: 0.5.0 · Ruby 3.1+

## Install

```bash
gem install seekmodo-sdk
```

Or in Bundler:

```ruby
gem "seekmodo-sdk", "~> 0.5"
```

Runtime dependencies: `faraday`, `jwt`.

## Quick starts

### Connector (HMAC)

```ruby
require "seekmodo/sdk"

signer = Seekmodo::Sdk::HmacSigner.new("your-tenant-id", "your-shared-secret")
breaker = Seekmodo::Sdk::CircuitBreaker.new(Seekmodo::Sdk::Storage::Memory::BreakerStore.new)
client = Seekmodo::Sdk::Connector::Client.new(signer, breaker: breaker)

results = client.search({ "q" => "red running shoes", "per_page" => 24 })
client.index(documents, action: "upsert") # auto-chunks at 500
client.tenant_snapshot # POST /v1/tenant.snapshot
```

### Storefront (JWT)

```ruby
client = Seekmodo::Sdk::Storefront::Client.new(
  tenant_id: "redline",
  get_token: -> { connector.browser_token["token"] }
)

hits = client.search({ "q" => "spark plug" })
recs = client.recommend.related({ "source_doc_id" => "sku-123" })
bundles = client.bundle.suggest({ "source_doc_id" => "sku-123" })
```

### Admin

```ruby
admin = Seekmodo::Sdk::Admin::Client.new(admin_key: ENV.fetch("MCP_ADMIN_KEY"))

synonyms = admin.list_synonyms("redline")
admin.add_synonym("redline", { "synonyms" => %w[spark plug] })
pins = admin.list_pins("redline")
ltr = admin.ltr_status("redline")
top = admin.analytics_top_queries("redline", window: "7d")
zeros = admin.analytics_zero_results("redline")
```

### MCP JSON-RPC

```ruby
# HMAC (tenant connector)
mcp = Seekmodo::Sdk::Mcp::Client.new(signer: signer)
mcp.initialize_session({ "clientInfo" => { "name" => "my-agent" } })
tools = mcp.tools_list
result = mcp.tools_call("search", { "q" => "brake pads" })

# Operator bearer
mcp = Seekmodo::Sdk::Mcp::Client.new(
  operator_token: ENV.fetch("SEEKMODO_OPERATOR_TOKEN"),
  tenant_id: "redline"
)
mcp.tools_call("analytics.zero_results", { "limit" => 10 })
```

### Tools registry

```ruby
registry = Seekmodo::Sdk::Tools::Registry.new(
  connector: connector_client,
  admin: admin_client,
  tenant_id: "redline"
)
registry.call("search", { "q" => "oil filter" })
registry.call("synonyms.list", {})
```

## Public surface

| Module / class | What it does |
|----------------|--------------|
| `Connector::Client` | `search`, `index`, `events`, `tenant_handshake`, `tenant_snapshot`, `browser_token`, `tools`, `health` |
| `HmacSigner` | Builds the three `X-Seekmodo-*` headers |
| `CircuitBreaker` | Three-state FSM (closed/open/half_open) with pluggable storage |
| `TenantSnapshot` | Polls `tenant.snapshot` with stale-while-revalidate cache |
| `ModeFsm` | Resolves effective connector mode |
| `AutoPromoter` | Walks `active` tenants through shadow → enforce |
| `Pairing` | Verifies EdDSA pairing JWTs against Seekmodo JWKS |
| `BrowserToken` | Mints `/v1/tenants/token` browser JWTs with TTL-aware caching |
| `EventsQueue` | Batches events into single `POST /v1/events` calls |
| `Events::ClickBeacon` | Pure-function payload builders for beacons |
| `Storefront::Client` | Typed `search`, `suggest`, `search_by_image`, `chat`, `event`, `recommend.*`, `bundle.suggest` |
| `Admin::Client` | Typed admin tools + generic `call(tool, body, tenant_id:)` |
| `Mcp::Client` | `initialize_session`, `tools_list`, `tools_call`, `ping` |
| `Tools::Registry` | Routes normalized tool names to connector or admin |

## Wire contract tests

Fixtures under `spec/contracts/fixtures/` mirror the PHP SDK contract pack.

```bash
bundle install
bundle exec rspec
bundle exec rubocop
```

## Versioning

Follows semver. Breaking wire or type changes are major bumps; new methods and optional fields are minors; bug fixes are patches.

## Links

- [Python SDK (reference parity)](https://github.com/numinix/seekmodo-python-sdk)
- [PHP SDK (wire fixtures source)](https://github.com/numinix/seekmodo-php-sdk)
