## [0.1.3] - 2026-09-06

- Add Co-op Bank support for bank transfers, balance and statement inquiries,
  transaction status queries, OAuth authentication, and normalized callbacks
- Add Jenga HQ support for bank transfers, mobile-money disbursements, account
  inquiries, forex rates, OAuth/RSA request signing, and verified payment IPNs
- Add card-payment capabilities for purchase, authorization, capture, and void,
  with Flutterwave, Paystack, and Pesapal gateway implementations
- Add Lightning Network support through LNbits, including separate invoice and
  admin API keys, invoice creation/status checks, outbound payments and
  reconciliation, and verified webhook parsing
- Add immutable `Lipwa::Context` configuration snapshots with isolated,
  memoized gateway instances for multi-tenant and concurrent applications
- Add a capability-focused documentation site and rewrite the project README
- Add constrained decimal amounts and currency-safe arithmetic to `Lipwa::Money`
- Formalize transient HTTP retries with bounded exponential backoff and idempotency-safe writes
- Add structured HTTP logging with recursive credential and secret redaction
- Add `idempotency_key:` support across gateway calls via the `Idempotency-Key` header

## [0.1.2] - 2026-08-29

- Add a Rails API example covering M-Pesa collection, disbursement, refunds,
  and webhook handling
- Refresh gem metadata and exclude the internal project plan from packaged gems

## [0.1.1]

- Add `Lipwa::HttpAdapter`, a Faraday-based HTTP wrapper
- Add `Lipwa::Gateways` container/registry for gateway implementations
- Wire dry-rb dependencies into the gemspec and `Lipwa.configure`
- Add M-Pesa OAuth2 client-credentials token handling
- Implement the `StkPush` capability
- Implement the `C2B` capability (validation/confirmation)
- Implement the `WebhookHandling` capability and `Lipwa::Webhook`
- Add VCR/WebMock cassettes for M-Pesa sandbox flows
- Implement the `Disbursement` capability (B2C/B2B)
- Implement the `StatusQuery` capability

## [0.1.0] - 2026-08-28

- Initial release
