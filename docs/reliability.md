---
title: Reliability
description: Results, retries, idempotency, and money safety.
---

<header class="page-title"><p class="eyebrow">Guide 05</p><h1>Reliability</h1><p class="lead">Expected failures are explicit, and automatic recovery is limited to operations safe to repeat.</p></header>

## Results and errors

| Type | Delivery | Meaning |
| --- | --- | --- |
| `ValidationError` | `Failure` | Input failed a capability contract |
| `GatewayError` | `Failure` | Network or provider HTTP failure |
| `WebhookParseError` | `Failure` | Invalid inbound JSON |
| `ConfigurationError` | raised | Missing or invalid setup |
| `UnsupportedProviderError` | raised | No webhook parser registered |

`Lipwa::Response` exposes `success?`, `provider_reference`, `message`,
`code`, and `raw`.

## Retry policy

Lipwa retries transient network exceptions and HTTP 429, 500, 502, 503, and
504 at most twice. Backoff begins at 0.5 seconds, doubles with up to 50%
jitter, and caps waits at 5 seconds. Server `Retry-After` and
`RateLimit-Reset` values are honored within that cap.

Safe reads retry automatically. Writes retry only with `Idempotency-Key`.

## Decimal money

{% highlight ruby %}subtotal = Lipwa::Money.new(amount: "199.95", currency: "KES")
fee = Lipwa::Money.new(amount: "5.05", currency: "KES")

total = subtotal + fee
total.to_s       # => "205.0 KES"
total > subtotal # => true{% endhighlight %}

Amounts and results are non-negative. Addition, subtraction, and comparison
across currencies raise `ArgumentError`. Currency conversion is never hidden.

## Async reconciliation

1. Persist a pending operation and idempotency key before calling the API.
2. Store the synchronous provider reference.
3. Verify and process callbacks idempotently.
4. Use status query where supported to reconcile missing callbacks.
5. Treat acknowledgements and callbacks as repeatable messages.

<nav class="doc-nav"><a href="{{ '/webhooks/' | relative_url }}">← Webhooks</a><a href="{{ '/' | relative_url }}">Home →</a></nav>
