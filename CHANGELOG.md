## [0.1.1]

- Add structured HTTP logging with recursive credential and secret redaction
- Add `idempotency_key:` support across gateway calls via the `Idempotency-Key` header
- Add Jenga receive-payment IPN parsing and Basic Auth signature verification
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
