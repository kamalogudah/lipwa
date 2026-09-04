---
title: Capabilities
description: Reference for Lipwa payment operations.
---

<header class="page-title"><p class="eyebrow">Guide 02</p><h1>Capabilities</h1><p class="lead">A capability describes a payment flow. Gateways include only the modules they support.</p></header>

{% highlight ruby %}gateway = Lipwa.gateway(:jenga)
gateway.capability?(:bank_transfer) # => true{% endhighlight %}

| Capability | Methods | Gateways |
| --- | --- | --- |
| `stk_push` | `stk_push` | M-Pesa |
| `c2b` | `register_urls`, `simulate` | M-Pesa |
| `disbursement` | `disburse` | M-Pesa, Jenga |
| `status_query` | `status` | M-Pesa |
| `refund` | `refund` | M-Pesa |
| `bank_transfer` | `transfer`, `balance`, `statement` | Co-op, Jenga |
| `lightning_invoice` | `create_invoice`, `check_invoice` | LNbits-backed gateways |

Lightning invoice amounts are positive integer satoshis (`amount_sats`), not
`Lipwa::Money` values. A created invoice's BOLT11 string is stored in
`response.raw["payment_request"]`; its payment hash is
`response.provider_reference`. Checking an unpaid invoice still returns
`Success(Response)`, with `response.success? == false`.


## Collection

{% highlight ruby %}mpesa = Lipwa.gateway(:mpesa)

mpesa.stk_push(
  amount: Lipwa::Money.new(amount: 100, currency: "KES"),
  phone_number: "254712345678",
  account_reference: "ORDER-123",
  callback_url: "https://example.com/webhooks/mpesa"
)

mpesa.register_urls(
  validation_url: "https://example.com/mpesa/validation",
  confirmation_url: "https://example.com/mpesa/confirmation"
)

mpesa.simulate(
  amount: Lipwa::Money.new(amount: 100, currency: "KES"),
  phone_number: "254712345678",
  bill_ref_number: "ORDER-123"
){% endhighlight %}

`simulate` is for M-Pesa sandbox testing.

## Disbursement, status, and refund

{% highlight ruby %}mpesa.disburse(
  command_id: "BusinessPayment",
  amount: Lipwa::Money.new(amount: 500, currency: "KES"),
  party_b: "254712345678",
  remarks: "Supplier payout",
  result_url: "https://example.com/mpesa/payout/result",
  queue_timeout_url: "https://example.com/mpesa/payout/timeout"
)

mpesa.status(
  transaction_id: "OEI2AK4Q16",
  remarks: "Reconcile order",
  result_url: "https://example.com/mpesa/status/result",
  queue_timeout_url: "https://example.com/mpesa/status/timeout"
)

mpesa.refund(
  transaction_id: "OEI2AK4Q16",
  amount: Lipwa::Money.new(amount: 100, currency: "KES"),
  remarks: "Customer refund",
  result_url: "https://example.com/mpesa/refund/result",
  queue_timeout_url: "https://example.com/mpesa/refund/timeout"
){% endhighlight %}

M-Pesa B2C command IDs are `SalaryPayment`, `BusinessPayment`, and
`PromotionPayment`. B2B supports `BusinessPayBill`, `BusinessBuyGoods`, and
`MerchantToMerchantTransfer` and requires `account_reference`.

## Bank operations

{% highlight ruby %}bank = Lipwa.gateway(:jenga)

bank.transfer(
  rail: :pesalink,
  amount: Lipwa::Money.new(amount: "2500.00", currency: "KES"),
  source_account: "00123456789",
  destination_account: "00987654321",
  destination_name: "Amina N.",
  reference: "INV-1042"
)

bank.balance(account_number: "00123456789")
bank.statement(account_number: "00123456789",
               from_date: Date.new(2026, 8, 1),
               to_date: Date.new(2026, 8, 31)){% endhighlight %}

Rails are `internal`, `rtgs`, `pesalink`, `swift`, and `bill_payment`,
subject to provider availability. RTGS/SWIFT require
`destination_bank_code`; bill payment requires `biller_code`. Jenga also
exposes `forex_rates`.

<nav class="doc-nav"><a href="{{ '/getting-started/' | relative_url }}">← Getting started</a><a href="{{ '/gateways/' | relative_url }}">Gateways →</a></nav>
