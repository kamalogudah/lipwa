---
title: Webhooks
description: Parse and verify M-Pesa and Jenga callbacks.
---

<header class="page-title"><p class="eyebrow">Guide 04</p><h1>Webhooks</h1><p class="lead">Normalize provider payloads, then perform the provider-specific trust check before changing financial state.</p></header>

## Parse

{% highlight ruby %}result = Lipwa::Webhook.parse_webhook(
  provider: :mpesa,
  body: request.body.read,
  headers: request.headers.to_h
)

result.either(
  ->(event) { process_event(event) },
  ->(error) { head :bad_request }
){% endhighlight %}

`WebhookEvent` exposes `provider`, `event_type`, `success?`,
`provider_reference`, `message`, `raw`, and `verify_signature`.

## Verify M-Pesa

Daraja does not cryptographically sign callbacks. Lipwa checks the remote
address against Safaricom's published callback IP list:

{% highlight ruby %}return head :forbidden unless event.verify_signature(
  source_ip: request.remote_ip
){% endhighlight %}

Configure trusted proxies carefully so clients cannot spoof forwarded IPs.
Event types are `stk_callback`, `c2b`, `transaction_status`,
`disbursement`, and `refund`.

## Verify Jenga

Jenga receive-payment IPNs normalize to `receive_payment`:

{% highlight ruby %}return head :forbidden unless event.verify_signature(
  username: ENV.fetch("JENGA_WEBHOOK_USERNAME"),
  password: ENV.fetch("JENGA_WEBHOOK_PASSWORD")
){% endhighlight %}

## Processing checklist

1. Retain the raw body and parse it through Lipwa.
2. Verify using provider-specific options.
3. Correlate by `provider_reference`.
4. Apply the transition idempotently inside a transaction.
5. Return quickly and defer slow work to a job.

<div class="callout"><strong>Never credit from an unverified callback.</strong> Parsing normalizes data; verification determines trust.</div>

<nav class="doc-nav"><a href="{{ '/gateways/' | relative_url }}">← Gateways</a><a href="{{ '/reliability/' | relative_url }}">Reliability →</a></nav>
