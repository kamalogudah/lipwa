---
title: Getting started
description: Install Lipwa, configure a gateway, and make your first request.
---

<header class="page-title"><p class="eyebrow">Guide 01</p><h1>Getting started</h1><p class="lead">Install the gem, configure one gateway, and handle the result explicitly.</p></header>

## Install and configure

{% highlight bash %}bundle add lipwa{% endhighlight %}

{% highlight ruby %}require "lipwa"

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
end{% endhighlight %}

## Make a request

{% highlight ruby %}result = Lipwa.gateway(:mpesa).stk_push(
  amount: Lipwa::Money.new(amount: "100.00", currency: "KES"),
  phone_number: "254712345678",
  account_reference: "ORDER-123",
  callback_url: "https://payments.example.com/webhooks/mpesa",
  idempotency_key: "stk-order-123"
)

result.either(
  ->(response) { Payment.update!(provider_reference: response.provider_reference) },
  ->(error) { logger.error(error.message) }
){% endhighlight %}

<div class="callout"><strong>Acceptance is not settlement.</strong> STK Push, disbursement, refund, and status calls are asynchronous. Process the later verified callback for the final result.</div>

## Initiator credentials

Disbursement, status, and refund also require:

{% highlight ruby %}Lipwa::Gateways::Mpesa.configure do |config|
  config.initiator_name = ENV.fetch("MPESA_INITIATOR_NAME")
  config.initiator_password = ENV.fetch("MPESA_INITIATOR_PASSWORD")
  config.security_credential_cert =
    File.read(ENV.fetch("MPESA_CERTIFICATE_PATH"))
end{% endhighlight %}

Sandbox and production certificates differ. Keep certificate content outside
source control.

## Idempotency

Reuse one stable `idempotency_key` when retrying one logical write. Lipwa
retries safe reads automatically, but writes only when this key is present.
The provider controls key retention and duplicate detection.

<nav class="doc-nav"><a href="{{ '/' | relative_url }}">← Home</a><a href="{{ '/capabilities/' | relative_url }}">Capabilities →</a></nav>
