# Lipwa — Plan

Unified Ruby gem for accepting and disbursing payments across African payment
providers — cards *and* non-card rails (mobile money, bank APIs, USSD push,
B2B/B2C disbursements). Spiritually `active_merchant`, but the base
abstraction is payment-*flow* shaped, not card-transaction shaped, and the
implementation style follows [dry-rb](https://dry-rb.org) conventions the
way [`arafa`](https://github.com/kamalogudah/arafa) does: typed value
objects, a `Result`/monad-based control flow instead of exceptions for
expected failures, a container-based gateway registry, and
`dry-configurable` for per-gateway settings.

## 1. Why not just copy ActiveMerchant's shape

ActiveMerchant's core contract (`purchase`, `authorize`, `capture`, `void`,
`refund`) assumes a card token/reference you hold and act on synchronously.
Most African rails don't work that way:

- **M-Pesa STK Push (Daraja)** — you *initiate* a push to the payer's phone,
  then get the actual result later via an async **callback**. There's no
  synchronous "yes it worked" response.
- **M-Pesa C2B** — payer initiates from their phone (paybill/till), your
  system only receives a **validation** webhook then a **confirmation**
  webhook.
- **M-Pesa B2C / B2B** — you're disbursing, not collecting. Different
  direction of money flow entirely.
- **Co-op Bank / Jenga (Equity)** — bank-account-to-bank-account transfers,
  balance/statement queries, bill payment, and *also* mobile money and card
  rails bundled behind one API key.

So the gem needs a capability model, not a single fixed interface: a gateway
declares which capabilities it supports (`:purchase`, `:stk_push`, `:c2b`,
`:disbursement`, `:refund`, `:status_query`, `:webhook_handling`, ...) and
only those methods are expected to exist on it.

## 2. Design principles (dry-rb style, per `arafa`)

- **Functional core, thin I/O shell.** Business/validation logic is pure
  where possible; HTTP calls are isolated behind an adapter object so they're
  easy to stub in tests.
- **No exceptions for expected failure modes.** Public gateway methods
  return `Dry::Monads::Result` (`Success(Lipwa::Response)` /
  `Failure(Lipwa::Error)`). Exceptions are reserved for programmer errors
  (bad config, unknown capability) — same split `arafa` uses.
- **Immutable value objects everywhere.** Requests, responses, money
  amounts, and credentials are `Dry::Struct` instances built from
  `Dry::Types`, not hashes. No mutation after construction.
- **Schema-validated input at the boundary.** Every gateway call validates
  its params through a `Dry::Validation::Contract` before touching the
  network, so a bad phone number or missing till number fails fast with a
  structured error, not a cryptic HTTP 400 from the provider.
- **Config via `Dry::Configurable`.** Each gateway class exposes its own
  settable, typed config block (`consumer_key`, `shortcode`, `passkey`,
  `env: :sandbox | :production`, timeouts). Global `Lipwa.configure` sets
  shared defaults (logger, default timeout, Faraday adapter). For
  multi-tenant applications, `Lipwa.context` snapshots those defaults and
  applies isolated per-gateway overrides without mutating process-wide state.
- **Registry via `Dry::Container` + `Dry::System`-style auto-registration.**
  `Lipwa::Gateways.register(:mpesa, Lipwa::Gateways::Mpesa)` — lets
  consumers do `Lipwa.gateway(:mpesa).stk_push(...)` without knowing the
  class name, and lets the gem add providers later without touching a
  central case statement.
- **Composable capabilities as modules**, not a fat base class with
  `raise NotImplementedError` stubs. `include Lipwa::Capabilities::StkPush`
  brings in `#stk_push` plus its own contract; a gateway only includes what
  it actually supports. Calling an uninlcuded capability is a `NoMethodError`
  at the Ruby level — no silent "not supported" runtime surprises.
- **Explicit over magic**, small single-purpose objects, no monkey-patching
  of core classes — same restraint dry-rb libraries hold to.

## 3. Core abstractions

```
Lipwa::Money                  # Dry::Struct — amount (Integer, minor units) + currency (ISO 4217)
Lipwa::Response               # Dry::Struct — success, provider_reference, raw, message, code
Lipwa::Error                  # base StandardError; subclasses: ConfigurationError,
                               #   ValidationError, GatewayError, UnsupportedCapabilityError
Lipwa::Gateway                # abstract base: holds Dry::Configurable settings,
                               #   an #http adapter, #capability?(name)
Lipwa::Capabilities::*        # one module per flow shape (below)
Lipwa::Contracts::*           # Dry::Validation::Contract per request type
Lipwa::Webhook                # inbound-callback parsing/verification helper
Lipwa::Gateways                # the Dry::Container registry + .register/.[] /.gateway
```

Capability modules (each with its own request/response Structs + contract):

| Capability             | Method(s)                          | Used by (initial) |
|-------------------------|-------------------------------------|--------------------|
| `Purchase`              | `#purchase`                         | card gateways (later) |
| `Authorize`/`Capture`   | `#authorize`, `#capture`, `#void`   | card gateways (later) |
| `Refund`                | `#refund`                           | most gateways |
| `StkPush`               | `#stk_push`                         | M-Pesa |
| `C2B`                   | `#register_urls`, `#simulate`       | M-Pesa |
| `Disbursement` (B2C/B2B)| `#disburse`                         | M-Pesa, Jenga |
| `BankTransfer`          | `#transfer`, `#balance`, `#statement` | Co-op Bank, Jenga |
| `StatusQuery`           | `#status`                           | all async flows |
| `WebhookHandling`       | `.parse_webhook`, `#verify_signature` | M-Pesa, Co-op, Jenga |
| `LightningInvoice`      | `#create_invoice`, `#check_invoice` | LNbits |

## 4. Directory structure

```
lib/lipwa.rb
lib/lipwa/version.rb
lib/lipwa/types.rb                 # Dry::Types module (Lipwa::Types)
lib/lipwa/money.rb
lib/lipwa/response.rb
lib/lipwa/errors.rb
lib/lipwa/gateway.rb               # abstract base
lib/lipwa/gateways.rb              # Dry::Container registry
lib/lipwa/http_adapter.rb          # Faraday wrapper, retries/timeouts/logging
lib/lipwa/webhook.rb
lib/lipwa/capabilities/
  purchase.rb
  authorize.rb
  refund.rb
  stk_push.rb
  c2b.rb
  disbursement.rb
  bank_transfer.rb
  status_query.rb
  webhook_handling.rb
lib/lipwa/contracts/
  stk_push_contract.rb
  disbursement_contract.rb
  ...
lib/lipwa/gateways/
  mpesa.rb
  mpesa/auth.rb                    # OAuth token caching for Daraja
  coop_bank.rb
  jenga.rb
test/
  support/shared_examples/          # e.g. "a disbursement capability"
  gateways/mpesa_test.rb
  ...
```

## 5. Provider notes (drives what the abstractions must support)

- **Safaricom Daraja (M-Pesa)** — OAuth2 client-credentials token (cache +
  auto-refresh), STK Push (Lipa Na M-Pesa Online), C2B validation/
  confirmation webhooks, B2C, B2B, Transaction Status, Account Balance.
  Sandbox and production have different base URLs and shortcodes.
- **Co-op Bank Developer Portal** — API-key + OAuth, account inquiry, funds
  transfer (internal/RTGS/PesaLink), bill payments, statement/balance
  queries, M-Pesa integration passthrough.
- **Jenga HQ (Equity)** — OAuth2 + request signing (private key signature
  header per request), send money (mobile money/bank/RTGS/SWIFT), bill
  payments, receive payments (webhook), forex rates, account services.
- Common shape across all three: OAuth-ish token acquisition, HMAC/RSA
  request signing or bearer tokens, sandbox vs. production hosts, and
  async confirmation via webhook for anything collection-related. This is
  why `HttpAdapter` needs pluggable auth strategies and `Webhook` needs
  pluggable signature verification, rather than being M-Pesa-specific.
- **LNbits (Bitcoin Lightning Network)** — self-hosted or hosted instance,
  plain REST/JSON API, static `X-Api-Key` header auth (no OAuth, no request
  signing). Invoices are BOLT11-denominated in satoshis, not ISO-4217
  currency. No gRPC/websocket streaming needed (unlike talking to a raw
  LND/CLN node directly) — this is why it was picked as the first Lightning
  backend: it fits the existing `HttpAdapter`/`AuthStrategies` shape with no
  new dependencies. LNbits does not sign its outbound payment webhooks, so
  verification uses an integrator-minted shared-secret token embedded in the
  webhook URL rather than an HMAC (see `LightningInvoice` capability notes).
  A raw LND/CLN gateway (gRPC + macaroon auth + `SubscribeInvoices` streaming)
  is a possible future gateway but is out of scope for now.

## 6. Example usage (target API)

```ruby
Lipwa.configure do |config|
  config.logger = Rails.logger
  config.default_timeout = 10
end

Lipwa::Gateways::Mpesa.configure do |c|
  c.env = :sandbox
  c.consumer_key = ENV["MPESA_CONSUMER_KEY"]
  c.consumer_secret = ENV["MPESA_CONSUMER_SECRET"]
  c.shortcode = ENV["MPESA_SHORTCODE"]
  c.passkey = ENV["MPESA_PASSKEY"]
end

result = Lipwa.gateway(:mpesa).stk_push(
  amount: Lipwa::Money.new(amount: 1_00, currency: "KES"),
  phone_number: "254712345678",
  account_reference: "ORDER-123",
  callback_url: "https://example.com/webhooks/mpesa"
)

result.either(
  ->(response) { response.provider_reference }, # CheckoutRequestID
  ->(error) { logger.error(error.message) }
)

# later, in the webhook controller:
event = Lipwa::Gateways::Mpesa.parse_webhook(request.body.read, headers: request.headers)
```

## 7. Dependencies

- `dry-types`, `dry-struct` — value objects
- `dry-monads` — `Result`/`Maybe`, `do` notation for chaining validate →
  call → parse
- `dry-validation` — request contracts
- `dry-configurable` — per-gateway and global config
- `dry-container` — gateway registry
- `faraday` (+ `faraday-retry`) — HTTP, kept behind `Lipwa::HttpAdapter` so
  it could be swapped later
- Dev/test: `webmock`, `vcr`, `minitest` (keeping the scaffolded framework).

## 8. Error handling strategy

- `Lipwa::Error` (base) → `ConfigurationError`, `ValidationError` (wraps a
  `Dry::Validation` result), `GatewayError` (wraps provider HTTP/timeout
  failures with `code`/`raw_body`), `UnsupportedCapabilityError`.
- Only `ConfigurationError` and `UnsupportedCapabilityError` are raised —
  these are programmer mistakes, fail loud at boot/call time.
- `ValidationError` and `GatewayError` are wrapped in `Failure(...)`, never
  raised, so callers must handle them explicitly via the monad.

## 9. Testing strategy

- Contract/shared-example suites per capability (e.g. "a StkPush
  capability") that every gateway implementing it must pass — catches
  interface drift as providers are added.
- VCR/WebMock cassettes per gateway for real (sanitized) sandbox
  request/response shapes; never hit live sandboxes in CI.
- Explicit tests for webhook signature verification with both valid and
  tampered payloads.

## 10. Phased roadmap

1. **Foundation** — `Types`, `Money`, `Response`, `Error` hierarchy,
   `HttpAdapter`, `Gateway` base, `Gateways` container/registry, dry
   dependencies wired into gemspec, CI green.
2. **M-Pesa (Daraja)** — OAuth token handling, `StkPush`, `C2B`
   (validation/confirmation), `WebhookHandling`. Highest-value target
   given ubiquity in Kenya.
3. **M-Pesa B2C/B2B** — `Disbursement` capability, `StatusQuery`,
   `Refund` (reversal).
4. **Co-op Bank** — `BankTransfer`, account inquiry/statement, reuse
   `WebhookHandling`/`StatusQuery` contracts against its shapes.
5. **Jenga HQ** — request-signing auth strategy (new `HttpAdapter` auth
   plugin), `BankTransfer`, `Disbursement`, receive-payment webhook.
6. **Hardening** — idempotency key support, structured logging/redaction
   of secrets, retry/backoff policy, richer `Money` (currency math via
   `dry-types` constrained decimals), documentation site, README rewrite.
7. **Card rails (stretch)** — Pesapal / Flutterwave / Paystack as
   `Purchase`/`Authorize`/`Capture`/`Void` implementers, proving the
   capability model also covers the ActiveMerchant-shaped case.
8. **Multi-tenant configuration** — introduce immutable `Lipwa::Context`
   snapshots, instance-owned gateway/global configuration, context-local
   gateway memoization, and concurrency/isolation coverage. Preserve
   `Lipwa.configure`, gateway-class `.configure`, and `Lipwa.gateway` as the
   backward-compatible process-wide API.
   Documentation milestone: README multi-tenant example and gateway context
   guide covering inheritance, snapshot timing, immutability, isolation,
   context-local memoization, retained tenant services, and secret redaction.
   Depends on #58, #57, and the provider migration issue; parent decision #33.
9. **Lightning Network (LNbits), receive-only** — new `AuthStrategies::ApiKey`,
   `LightningInvoice` capability (`#create_invoice`, `#check_invoice`),
   `Lipwa::Gateways::Lnbits`, `Lipwa::Webhooks::Lnbits` (shared-secret-token
   verification, no HMAC available from LNbits). Proves the capability model
   also covers a non-fiat, non-ISO-4217 rail. Outbound `pay_invoice` (spending
   sats, needs the LNbits admin/full key rather than invoice/read) is a
   later phase, not v1.

## 11. Decisions

- **Test framework**: `minitest`, as already scaffolded.
- **Currency scope**: KES-first. `Money`/contracts aren't hardcoded to
  KES, but no work goes into other currencies until a provider actually
  needs one.

- **Global and multi-tenant configuration**: retain `Lipwa.configure` and
  gateway-class `.configure` as process-wide defaults, and add explicit
  `Lipwa::Context` objects for tenant-specific overrides. A context snapshots
  global and provider configuration when it is built, owns and memoizes its
  gateway instances, and does not observe later global reconfiguration.
  Context configuration is mutable only during construction and frozen before
  use. No ambient thread-local current-tenant state is introduced.
  `Lipwa.gateway(:mpesa)` remains the backward-compatible process-wide lookup;
  `tenant_context.gateway(:mpesa)` resolves a separate context-owned instance.
  Retain one context per tenant, load secrets during construction, and replace
  the context to rotate credentials. Do not mutate gateway-class configuration
  per request. Context gateways retain HTTP log redaction for tenant secrets.
  This records parent decision #33; the README and gateway guide document the
  API after #58, #57, and provider migration.

## 12. Open questions to confirm before/while building

- Sync vs. async webhook story: does the gem ship a Rack/Rails-agnostic
  webhook *parser* only (current plan), or also engine/controller helpers?
  **Resolved for LNbits**: parser-only, same as M-Pesa — no Rack/Rails
  controller helper is being added for this gateway either. Still an open
  question for whether the gem ever adds one generically.
- LNbits webhook trust model: since LNbits doesn't HMAC-sign webhooks, v1
  uses an integrator-minted shared-secret token embedded in the `webhook_url`
  itself, verified via constant-time comparison, with `#check_invoice`
  required as an independent re-verification before crediting payment. Revisit
  if a future LNbits version/extension adds real HMAC signing — `WebhookEvent#verify_signature`
  already accepts provider-specific `**opts`, so a second verification mode
  could be added without an interface change.
