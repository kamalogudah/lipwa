# Lipwa example — Rails API app

A minimal Rails API app that exercises every capability the `lipwa` gem
exposes against Safaricom's M-Pesa Daraja API: STK Push, C2B (register +
sandbox simulate), disbursement (B2C/B2B), refund, and inbound webhook
handling. It uses the gem via a local path (`gem "lipwa", path: "../.."`),
so it always runs against this repo's working tree — handy both for
evaluating the gem and for manually smoke-testing changes while developing
it.

Each outbound call persists a `Transaction` row; each inbound webhook
persists a `WebhookEvent` row — so results are visible in the database, not
just in the response body. This app is not part of the released gem (see
the `examples/` exclusion in `../../lipwa.gemspec`).

## Setup

```bash
bundle install
bin/rails db:create db:migrate
cp .env.example .env   # then fill in your own Daraja sandbox credentials
bin/rails server
```

Credentials come from your own Daraja developer account
(https://developer.safaricom.co.ke/) — see `.env.example` for every
variable and what it's for. Without real credentials, calls will fail with
a `Lipwa::ConfigurationError` (missing config, HTTP 500) or a
`Lipwa::GatewayError` (Daraja rejected the call, HTTP 502) rather than
crashing — that's the gem's documented error-handling contract, not a bug
in this example.

Daraja requires **https** callback/result URLs, and its sandbox needs to
be able to reach them over the public internet — running this app locally,
that means tunneling it (e.g. `ngrok http 3000`) and setting `APP_HOST` in
`.env` to the tunnel's host (e.g. `abc123.ngrok-free.app`).

## Endpoints

| Method | Path | Capability |
| --- | --- | --- |
| POST | `/api/v1/stk_pushes` | `#stk_push` |
| POST | `/api/v1/c2b/register_urls` | `#register_urls` |
| POST | `/api/v1/c2b/simulate` | `#simulate` (sandbox only) |
| POST | `/api/v1/disbursements` | `#disburse` (B2C/B2B) |
| POST | `/api/v1/refunds` | `#refund` |
| POST | `/webhooks/mpesa/{stk,c2b,result,timeout}` | inbound callbacks |

### STK Push

```bash
curl -X POST http://localhost:3000/api/v1/stk_pushes \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "phone_number": "254712345678", "account_reference": "ORDER-123"}'
```

### C2B

```bash
curl -X POST http://localhost:3000/api/v1/c2b/register_urls

curl -X POST http://localhost:3000/api/v1/c2b/simulate \
  -H "Content-Type: application/json" \
  -d '{"amount": 100, "phone_number": "254712345678", "bill_ref_number": "ORDER-123"}'
```

### Disbursement (B2C / B2B)

```bash
# B2C
curl -X POST http://localhost:3000/api/v1/disbursements \
  -H "Content-Type: application/json" \
  -d '{"command_id": "SalaryPayment", "amount": 500000, "party_b": "254712345678", "remarks": "August salary"}'

# B2B
curl -X POST http://localhost:3000/api/v1/disbursements \
  -H "Content-Type: application/json" \
  -d '{"command_id": "BusinessPayBill", "amount": 1000000, "party_b": "600000", "remarks": "Supplier settlement", "account_reference": "INV-2026-08-001"}'
```

Requires `MPESA_INITIATOR_NAME`, `MPESA_INITIATOR_PASSWORD`, and
`MPESA_CERT_PATH` in `.env` — see the gem's own README ("Disbursement")
for what the certificate is and where to download it.

### Refund

```bash
curl -X POST http://localhost:3000/api/v1/refunds \
  -H "Content-Type: application/json" \
  -d '{"transaction_id": "OEI2AK4Q16", "amount": 100, "remarks": "Missing item"}'
```

Requires the same initiator credentials as disbursement.

## Inspecting results

```bash
bin/rails runner 'pp Transaction.order(:id).to_a'
bin/rails runner 'pp WebhookEvent.order(:id).to_a'
```

`WebhookEvent#verified` reflects `Lipwa::WebhookEvent#verify_signature` —
for M-Pesa that's a check against Safaricom's published callback IP
ranges, so it will be `false` for anything not actually sent by Daraja
(including hand-crafted test requests from your own machine).
