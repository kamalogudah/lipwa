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

## Lightning Network (LNbits)

LNbits is the only Lightning backend supported today. The authentication
strategy and capability-based gateway shape allow other REST-based Lightning
backends to register their own gateway class later without changing this API.

### Configuration

Configure the URL of your hosted or self-hosted LNbits instance and its scoped
invoice/read key. Do not supply an admin key: receiving payments only requires
the less-privileged invoice key.

```ruby
Lipwa::Gateways::Lnbits.configure do |config|
  config.base_url = ENV.fetch("LNBITS_BASE_URL")
  config.invoice_key = ENV.fetch("LNBITS_INVOICE_KEY")
end
```

### Usage

Lightning invoice amounts are positive integer satoshi amounts, rather than
`Lipwa::Money` values:

```ruby
lnbits = Lipwa.gateway(:lnbits)

invoice_result = lnbits.create_invoice(
  amount_sats: 2_100,
  memo: "Order ORDER-123",
  expiry: 900
)

invoice = invoice_result.value!
invoice.provider_reference       # payment_hash, used by #check_invoice
invoice.raw["payment_request"]   # BOLT11 string; render this as a QR code

status_result = lnbits.check_invoice(
  payment_hash: invoice.provider_reference
)

status = status_result.value!
status.success?       # true only when LNbits reports paid == true
status.raw["paid"]   # the provider's raw payment status
```

An unpaid invoice check is still a successful `Dry::Monads::Result`; inspect
`Lipwa::Response#success?` to distinguish paid from unpaid. `Failure` is
reserved for validation and transport errors.

### Webhooks

LNbits does not sign payment webhooks. Mint a strong per-invoice token, embed
it in the HTTPS webhook URL, and store it with the returned payment hash. A
valid token makes the callback a useful low-latency notification, but it is
not proof of payment: always call `check_invoice` before crediting the payer.

```ruby
require "securerandom"
require "uri"

# When creating the invoice:
webhook_token = SecureRandom.hex(32)
webhook_url = "https://payments.example.com/webhooks/lnbits?#{
  URI.encode_www_form(token: webhook_token)
}"

invoice_result = lnbits.create_invoice(
  amount_sats: 2_100,
  memo: "Order ORDER-123",
  webhook_url: webhook_url
)
invoice = invoice_result.value!

# Persist both values against the order. Never put an LNbits API key in the URL.
order.update!(
  lightning_payment_hash: invoice.provider_reference,
  lightning_webhook_token: webhook_token
)

# In the webhook controller/handler:
event_result = Lipwa::Webhook.parse_webhook(
  provider: :lnbits,
  body: request.body.read,
  headers: request.headers
)
event = event_result.value!
order = Order.find_by!(lightning_payment_hash: event.provider_reference)

verified = event.verify_signature(
  expected_token: order.lightning_webhook_token,
  provided_token: request.params["token"]
)
head :unauthorized and return unless verified

# Token verification alone is insufficient: ask LNbits for authoritative state.
status_result = lnbits.check_invoice(payment_hash: event.provider_reference)
status = status_result.value!
head :unprocessable_entity and return unless status.success?

order.credit_once!
head :ok
```

## Capability matrix

| Gateway | Capabilities |
| --- | --- |
| `:mpesa` | `stk_push`, `c2b`, `disbursement`, `status_query`, `refund` |
| `:coop_bank` | `bank_transfer`: transfer, balance, statement |
| `:jenga` | `bank_transfer`, `disbursement`, plus `forex_rates` |
| `:lnbits` | `lightning_invoice`: create and check receive-only invoices |

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
