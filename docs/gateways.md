---
title: Gateways
description: Configure M-Pesa, Co-op Bank, and Jenga HQ.
---

<header class="page-title"><p class="eyebrow">Guide 03</p><h1>Gateways</h1><p class="lead">Each provider owns its credentials and environment; HTTP defaults remain shared.</p></header>

## M-Pesa

{% highlight ruby %}Lipwa::Gateways::Mpesa.configure do |c|
  c.env = :sandbox
  c.consumer_key = ENV.fetch("MPESA_CONSUMER_KEY")
  c.consumer_secret = ENV.fetch("MPESA_CONSUMER_SECRET")
  c.shortcode = ENV.fetch("MPESA_SHORTCODE")
  c.passkey = ENV.fetch("MPESA_PASSKEY")
end{% endhighlight %}

Lipwa chooses the Daraja host and manages OAuth tokens.

## Co-op Bank

{% highlight ruby %}Lipwa::Gateways::CoopBank.configure do |c|
  c.env = :sandbox
  c.api_key = ENV.fetch("COOP_API_KEY")
  c.api_secret = ENV.fetch("COOP_API_SECRET")
  c.base_url = ENV["COOP_BASE_URL"]   # optional override
  c.token_url = ENV["COOP_TOKEN_URL"] # optional override
end{% endhighlight %}

`client_id` and `client_secret` are aliases for `api_key` and `api_secret`.

## Jenga HQ

{% highlight ruby %}Lipwa::Gateways::Jenga.configure do |c|
  c.env = :sandbox
  c.api_key = ENV.fetch("JENGA_API_KEY")
  c.merchant_code = ENV.fetch("JENGA_MERCHANT_CODE")
  c.consumer_secret = ENV.fetch("JENGA_CONSUMER_SECRET")
  c.private_key = File.read(ENV.fetch("JENGA_PRIVATE_KEY_PATH"))
  c.source_account = ENV.fetch("JENGA_SOURCE_ACCOUNT")
  c.source_name = ENV.fetch("JENGA_SOURCE_NAME")
  c.country_code = "KE"
  c.partner_id = ENV["JENGA_PARTNER_ID"]
end{% endhighlight %}

Lipwa obtains bearer tokens and signs provider requests.

## Per-gateway HTTP settings

{% highlight ruby %}Lipwa::Gateways::Jenga.configure do |c|
  c.timeout = 20
  c.open_timeout = 5
  c.logger = MyStructuredLogger.new
end{% endhighlight %}

Logs recursively redact authorization, credentials, cookies, passwords,
tokens, and secret-like fields.

<nav class="doc-nav"><a href="{{ '/capabilities/' | relative_url }}">← Capabilities</a><a href="{{ '/webhooks/' | relative_url }}">Webhooks →</a></nav>
