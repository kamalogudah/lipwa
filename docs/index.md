---
title: Home
description: Unified, capability-based African payment APIs for Ruby.
---

<section class="hero"><div>
<p class="eyebrow">Payment flows, honestly modeled</p>
<h1>One Ruby API. Only the capabilities you need.</h1>
<p class="lead">Lipwa unifies mobile money, bank transfers, payouts, and asynchronous callbacks without pretending every provider behaves like a card gateway.</p>
<div class="actions"><a class="button" href="{{ '/getting-started/' | relative_url }}">Get started</a><a class="button secondary" href="{{ '/capabilities/' | relative_url }}">Explore capabilities</a></div>
</div><div class="terminal"><div class="terminal-bar"><span class="terminal-dot"></span><span class="terminal-dot"></span><span class="terminal-dot"></span></div>
{% highlight ruby %}gateway = Lipwa.gateway(:mpesa)

result = gateway.stk_push(
  amount: Lipwa::Money.new(
    amount: "100.00",
    currency: "KES"
  ),
  phone_number: "254712345678",
  account_reference: "ORDER-123",
  callback_url: callback_url,
  idempotency_key: "stk-order-123"
)

result.fmap(&:provider_reference){% endhighlight %}
</div></section>

## Designed around real payment flows

<div class="grid">
<article class="card"><span class="number">01</span><h3>Capability first</h3><p>Gateways expose operations they truly implement. Inspect support with <code>capability?</code> and route deliberately.</p></article>
<article class="card"><span class="number">02</span><h3>Failure explicit</h3><p>Validation and provider failures travel through <code>Dry::Monads::Result</code>.</p></article>
<article class="card"><span class="number">03</span><h3>Async aware</h3><p>Request acknowledgement and final outcome stay distinct. Normalized webhook events complete the flow.</p></article>
</div>

## Supported gateways

| Gateway | What it can do |
| --- | --- |
| M-Pesa | STK Push, C2B, B2C/B2B, status, refunds |
| Co-op Bank | Transfers, balances, and statements |
| Jenga HQ | Bank/mobile transfers, account queries, forex |

<div class="callout"><strong>Start with a flow, not a provider.</strong> Choose the capability your product needs, then select a gateway that advertises it.</div>

<nav class="doc-nav"><span></span><a href="{{ '/getting-started/' | relative_url }}">Getting started →</a></nav>
