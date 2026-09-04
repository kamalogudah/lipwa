# Lipwa

Lipwa is a capability-based Ruby toolkit for African payment APIs. Mobile
money, bank transfers, payouts, and callbacks do not share one card-shaped
interface; each gateway exposes only the flows it supports.

```ruby
gateway = Lipwa.gateway(:mpesa)
gateway.capability?(:stk_push)      # => true
gateway.capability?(:bank_transfer) # => false
```

## What it provides

- Explicit, composable gateway capabilities
- Validated inputs and immutable decimal money values
- `Dry::Monads::Result` for expected validation and network failures
- Normalized responses and webhook events
- OAuth/signing strategies, timeouts, safe retries, and redacted logs

## Installation

```bash
bundle add lipwa
```

Lipwa supports Ruby 3.2 and newer.

## Quick start

```ruby
require "lipwa"

Lipwa.configure do |config|
  config.logger = Rails.logger
  config.default_timeout = 10
end

Lipwa::Gateways::Mpesa.configure do |config|
  config.env = :sandbox
  config.consumer_key = ENV.fetch("MPESA_CONSUMER_KEY")
  config.consumer_secret = ENV.fetch("MPESA_CONSUMER_SECRET")
  config.shortcode = ENV.fetch("MPESA_SHORTCODE")
  config.passkey = ENV.fetch("MPESA_PASSKEY")
end

result = Lipwa.gateway(:mpesa).stk_push(
  amount: Lipwa::Money.new(amount: "100.00", currency: "KES"),
  phone_number: "254712345678",
  account_reference: "ORDER-123",
  callback_url: "https://payments.example.com/webhooks/mpesa",
  idempotency_key: "stk-order-123"
)

result.either(
  ->(response) { puts response.provider_reference },
  ->(error) { warn error.message }
)
```

A successful STK response means M-Pesa accepted the request. The final payment
outcome arrives asynchronously at `callback_url`.

## Capability matrix

| Gateway | Capabilities |
| --- | --- |
| `:mpesa` | `stk_push`, `c2b`, `disbursement`, `status_query`, `refund` |
| `:coop_bank` | `bank_transfer`: transfer, balance, statement |
| `:jenga` | `bank_transfer`, `disbursement`, plus `forex_rates` |

Gateways that include `lightning_invoice` accept `amount_sats` as a positive
integer count of satoshis. Lightning amounts intentionally do not use
`Lipwa::Money` or `Types::Currency`. The BOLT11 invoice is available as
`response.raw["payment_request"]`, and `response.provider_reference` is its
payment hash.

## Money

`Lipwa::Money` stores non-negative amounts as constrained `BigDecimal` values.
Addition, subtraction, and comparison require matching currencies;
multiplication and division accept numeric scalars.

```ruby
price = Lipwa::Money.new(amount: "100.25", currency: "KES")
tax = Lipwa::Money.new(amount: "16.04", currency: "KES")

(price + tax).to_s # => "116.29 KES"
(price * 2).to_s   # => "200.5 KES"
```

Currency conversion is never implicit.

## Results and errors

Operations return `Success(Lipwa::Response)`, `Failure(Lipwa::ValidationError)`,
or `Failure(Lipwa::GatewayError)`. Configuration and unsupported-provider
errors are raised because they are programmer or deployment mistakes.

For asynchronous operations, persist `response.provider_reference` and
correlate it with a verified webhook. Never treat request acknowledgement as
the final transaction outcome.

## Documentation

- [Documentation home](docs/index.md)
- [Getting started](docs/getting-started.md)
- [Capabilities](docs/capabilities.md)
- [Gateway configuration](docs/gateways.md)
- [Webhooks](docs/webhooks.md)
- [Reliability and errors](docs/reliability.md)

## Development

```bash
bin/setup
bundle exec rake
bin/console
```

Tests use WebMock and sanitized VCR fixtures; they do not contact live provider
sandboxes.

## Contributing and license

Bug reports and pull requests are welcome on
[GitHub](https://github.com/kamalogudah/lipwa). Please follow the
[code of conduct](CODE_OF_CONDUCT.md). Lipwa is available under the
[MIT License](LICENSE.txt).
