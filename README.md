# Lipwa

Lipwa is a unified Ruby gem for accepting and disbursing payments across
African payment providers — mobile money, bank APIs, and (eventually) card
rails — behind one consistent, capability-based interface. It currently
ships a full integration with Safaricom's **M-Pesa Daraja API**: STK Push,
C2B, B2C/B2B disbursements, and inbound webhook handling.

Every gateway call returns a `Dry::Monads::Result`
(`Success(Lipwa::Response)` / `Failure(Lipwa::Error)`) instead of raising —
see [Error handling](#error-handling) below. Only genuine programmer
mistakes (bad config, calling a capability the gateway doesn't support) are
raised as exceptions.

## Installation

Install the gem and add it to the application's Gemfile by executing:

```bash
bundle add lipwa
```

If bundler is not being used to manage dependencies, install the gem by
executing:

```bash
gem install lipwa
```

## Configuration

Set gem-wide defaults once (logger, default timeout, Faraday adapter — all
optional):

```ruby
Lipwa.configure do |config|
  config.logger = Rails.logger
  config.default_timeout = 10
end
```

Then configure each gateway you use. For M-Pesa:

```ruby
Lipwa::Gateways::Mpesa.configure do |c|
  c.env = :sandbox # or :production
  c.consumer_key = ENV["MPESA_CONSUMER_KEY"]
  c.consumer_secret = ENV["MPESA_CONSUMER_SECRET"]
  c.shortcode = ENV["MPESA_SHORTCODE"]
  c.passkey = ENV["MPESA_PASSKEY"] # STK Push only

  # B2C/B2B disbursements only:
  c.initiator_name = ENV["MPESA_INITIATOR_NAME"]
  c.initiator_password = ENV["MPESA_INITIATOR_PASSWORD"]
  c.security_credential_cert = File.read(ENV["MPESA_CERT_PATH"])
end
```

`consumer_key`/`consumer_secret` authenticate every Daraja call (OAuth2
client-credentials, cached and auto-refreshed). `shortcode`/`passkey` are
only needed for STK Push and C2B. `initiator_name`/`initiator_password`/
`security_credential_cert` are only needed if you call `#disburse` — see
[Disbursement](#disbursement-b2c--b2b) for what the cert is and where to
get it. Configuring only what you actually use is fine; each capability
raises `Lipwa::ConfigurationError` at call time if something it needs is
missing, not at load time.

For Jenga HQ:

```ruby
Lipwa::Gateways::Jenga.configure do |c|
  c.env = :sandbox # or :production
  c.api_key = ENV["JENGA_API_KEY"]
  c.merchant_code = ENV["JENGA_MERCHANT_CODE"]
  c.consumer_secret = ENV["JENGA_CONSUMER_SECRET"]
  c.private_key = File.read(ENV["JENGA_PRIVATE_KEY_PATH"])
  c.source_account = ENV["JENGA_SOURCE_ACCOUNT"]
  c.source_name = ENV["JENGA_SOURCE_NAME"]
  c.country_code = "KE"
  c.partner_id = ENV["JENGA_PARTNER_ID"] # bill payments only
end
```

Jenga access tokens are cached and refreshed automatically. Each operation
is signed with the endpoint's required RSA-SHA256 formula and sent in the
`Signature` header. Register the matching public key in Jenga HQ; never
commit the private key.

Bank transfers support `:internal`, `:pesalink`, `:rtgs`, `:swift`, and
`:bill_payment` rails:

```ruby
result = Lipwa.gateway(:jenga).transfer(
  rail: :rtgs,
  amount: Lipwa::Money.new(amount: 1_000, currency: "KES"),
  source_account: ENV["JENGA_SOURCE_ACCOUNT"],
  destination_account: "0123456789",
  destination_bank_code: "68",
  destination_name: "Recipient Name",
  reference: "TRANSFER-123",
  narration: "Supplier payment"
)

Lipwa.gateway(:jenga).balance(account_number: ENV["JENGA_SOURCE_ACCOUNT"])
Lipwa.gateway(:jenga).statement(account_number: ENV["JENGA_SOURCE_ACCOUNT"])
Lipwa.gateway(:jenga).forex_rates(currency_code: "KES", amount: 1_000, to_currency: "USD")
```

Parse and authenticate Jenga receive-payment IPNs with the Basic Auth
credentials registered alongside the callback URL in Jenga HQ:

```ruby
result = Lipwa::Webhook.parse_webhook(
  provider: :jenga,
  body: request.body.read,
  headers: request.headers
)

event = result.value!
event.verify_signature(
  username: ENV["JENGA_WEBHOOK_USERNAME"],
  password: ENV["JENGA_WEBHOOK_PASSWORD"]
)
```

Fetch a configured gateway by name instead of referencing the class
directly:

```ruby
Lipwa.gateway(:mpesa).stk_push(...)
```

## Usage

### STK Push (Lipa Na M-Pesa Online)

Pushes a payment prompt to the payer's phone. The actual result of the
payment arrives later at `callback_url` — a successful call here only
confirms Daraja *accepted* the request, not that the customer paid.

```ruby
result = Lipwa.gateway(:mpesa).stk_push(
  amount: Lipwa::Money.new(amount: 100, currency: "KES"), # 100 = 1.00 KES, minor units
  phone_number: "254712345678",
  account_reference: "ORDER-123",
  callback_url: "https://example.com/webhooks/mpesa/stk"
)

result.either(
  ->(response) { response.provider_reference }, # CheckoutRequestID
  ->(error) { logger.error(error.message) }
)
```

### C2B (Customer to Business)

Registers the validation/confirmation webhook URLs Daraja calls when a
customer pays your paybill/till directly (outside STK Push), and — sandbox
only — simulates such a payment so you can exercise those URLs without a
real transaction.

```ruby
Lipwa.gateway(:mpesa).register_urls(
  validation_url: "https://example.com/webhooks/mpesa/validate",
  confirmation_url: "https://example.com/webhooks/mpesa/confirm"
)

# Sandbox only:
Lipwa.gateway(:mpesa).simulate(
  amount: Lipwa::Money.new(amount: 100, currency: "KES"),
  phone_number: "254712345678",
  bill_ref_number: "ORDER-123"
)
```

### Disbursement (B2C / B2B)

`#disburse` sends money out from your shortcode — to a customer's phone
(B2C: salaries, promotions, business payments) or to another business
(B2B: paybill/till settlement) — driven by `command_id` rather than two
separate methods:

```ruby
# B2C — pay out to a customer's phone
result = Lipwa.gateway(:mpesa).disburse(
  command_id: "SalaryPayment", # or "BusinessPayment" / "PromotionPayment"
  amount: Lipwa::Money.new(amount: 5_000_00, currency: "KES"),
  party_b: "254712345678", # payee MSISDN
  remarks: "August salary",
  result_url: "https://example.com/webhooks/mpesa/b2c/result",
  queue_timeout_url: "https://example.com/webhooks/mpesa/b2c/timeout",
  occasion: "August payroll"
)

# B2B — settle with another business shortcode
result = Lipwa.gateway(:mpesa).disburse(
  command_id: "BusinessPayBill", # or "BusinessBuyGoods" / "MerchantToMerchantTransfer"
  amount: Lipwa::Money.new(amount: 10_000_00, currency: "KES"),
  party_b: "600000", # payee business shortcode
  remarks: "Supplier settlement",
  result_url: "https://example.com/webhooks/mpesa/b2b/result",
  queue_timeout_url: "https://example.com/webhooks/mpesa/b2b/timeout",
  account_reference: "INV-2026-08-001" # required for B2B command IDs
)
```

Like STK Push, `#disburse` only confirms Daraja *accepted* the request
(`ConversationID`) — the outcome (success or failure of the actual
payout) arrives later at `result_url`.

**About `security_credential_cert`**: Daraja requires every B2C/B2B
request to carry a `SecurityCredential` — your initiator password,
RSA-encrypted with Safaricom's public certificate. Lipwa does this
encryption for you (see `Lipwa::Gateways::Mpesa::SecurityCredential`); you
just need to supply the certificate itself as PEM/DER content via
`security_credential_cert`. Download it from the Daraja developer
portal — the **Test Credentials** page for sandbox, or your app's
production certificate for production — since sandbox and production use
different certificates and mixing them up causes every B2C/B2B request to
fail. Don't hardcode certificate content in source; load it from a file or
secret store, e.g. `c.security_credential_cert = File.read("certs/mpesa_production.cer")`.

### Refund

`#refund` reverses a completed M-Pesa transaction by its `TransactionID`
(Daraja's Transaction Reversal API):

```ruby
result = Lipwa.gateway(:mpesa).refund(
  transaction_id: "OEI2AK4Q16",
  amount: Lipwa::Money.new(amount: 100_00, currency: "KES"),
  remarks: "Missing item",
  result_url: "https://example.com/webhooks/mpesa/reversal/result",
  queue_timeout_url: "https://example.com/webhooks/mpesa/reversal/timeout",
  occasion: "Customer complaint"
)
```

Like `#disburse`, `#refund` only confirms Daraja *accepted* the reversal
request — the outcome arrives later at `result_url`. It requires the same
`security_credential_cert` as `#disburse` — see
[Disbursement](#disbursement-b2c--b2b) for what the cert is and where to
get it.

### Webhook handling

Daraja delivers STK Push results and C2B validation/confirmation as
inbound HTTP callbacks. Parse and (for M-Pesa) verify them with
`Lipwa::Webhook`:

```ruby
# in your webhook controller
result = Lipwa::Webhook.parse_webhook(provider: :mpesa, body: request.body.read, headers: request.headers)

result.either(
  lambda do |event|
    if event.verify_signature(source_ip: request.remote_ip)
      # event.event_type   => :stk_callback or :c2b
      # event.success?     => whether the STK push succeeded (always true for C2B —
      #                       C2B callbacks only fire for an already-completed payment)
      # event.provider_reference => CheckoutRequestID (STK) or TransID (C2B)
      handle(event)
    else
      head :forbidden
    end
  end,
  ->(error) { logger.error(error.message) }
)
```

M-Pesa doesn't cryptographically sign callbacks, so `verify_signature`
checks the request's source IP against Safaricom's published callback IP
ranges instead — always call it before trusting a callback's contents.

### `Lipwa::Money`

Amounts are always a `Lipwa::Money` — an immutable value object storing
minor currency units (e.g. `100` = KES 1.00) plus an ISO 4217 currency
code (defaults to `"KES"`):

```ruby
Lipwa::Money.new(amount: 100, currency: "KES")
```

## Error handling

Gateway methods (`#stk_push`, `#register_urls`, `#simulate`, `#disburse`)
never raise for expected failure modes — they return a
`Dry::Monads::Result`:

- `Success(Lipwa::Response)` — `#success?`, `#provider_reference`,
  `#message`, `#code`, `#raw` (the parsed provider response). Note a
  `Success` can still wrap `response.success? == false` — Daraja
  synchronous validation errors (bad shortcode, malformed request) come
  back as a normal 200 response with a non-zero `ResponseCode`.
- `Failure(Lipwa::ValidationError)` — your params failed contract
  validation before any network call was made.
- `Failure(Lipwa::GatewayError)` — the HTTP call itself failed (timeout,
  connection error) or the provider returned an HTTP error status.

`Lipwa::ConfigurationError` and `Lipwa::UnsupportedCapabilityError` are
raised, not wrapped — they represent programmer/ops mistakes (missing
credentials, calling a capability a gateway doesn't include) that should
fail loudly at call time rather than be routed through error-handling
code.

## Development

After checking out the repo, run `bin/setup` to install dependencies.
Then, run `rake test` to run the tests. You can also run `bin/console` for
an interactive prompt that will allow you to experiment.

Tests run against hand-authored VCR cassettes
(`test/fixtures/vcr_cassettes/mpesa/`) with fake sandbox credentials —
they never hit Safaricom's real sandbox, so no network access or real
credentials are needed to run the suite.

To install this gem onto your local machine, run `bundle exec rake
install`. To release a new version, update the version number in
`version.rb`, and then run `bundle exec rake release`, which will create a
git tag for the version, push git commits and the created tag, and push
the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/kamalogudah/lipwa. This project is intended to be a
safe, welcoming space for collaboration, and contributors are expected to
adhere to the [code of conduct](https://github.com/kamalogudah/lipwa/blob/master/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the
[MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Lipwa project's codebases, issue trackers,
chat rooms and mailing lists is expected to follow the
[code of conduct](https://github.com/kamalogudah/lipwa/blob/master/CODE_OF_CONDUCT.md).
