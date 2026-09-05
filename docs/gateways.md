---
title: Gateways
description: Configure M-Pesa, Co-op Bank, and Jenga HQ.
---

<header class="page-title"><p class="eyebrow">Guide 03</p><h1>Gateways</h1><p class="lead">Configure process-wide defaults or isolate each tenant's credentials and HTTP settings in a context.</p></header>

## Process-wide defaults

`Lipwa.configure` sets shared `logger`, `default_timeout`, and Faraday `adapter`
defaults. Gateway-class `.configure` sets provider credentials, environment, and
HTTP overrides, as shown below. These APIs and `Lipwa.gateway(:mpesa)` remain
supported and backward compatible; existing single-tenant applications do not
need to adopt contexts.

Configure defaults at boot before resolving gateways or constructing contexts.
`Lipwa.gateway(:mpesa)` lazily constructs and memoizes one process-wide gateway.
Its provider and shared settings are captured on the first lookup; later
configuration changes do not update that instance. Direct construction with
`Lipwa::Gateways::Mpesa.new` captures defaults at construction time instead.

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

## Contexts

`Lipwa.context { |config| ... }` (or `Lipwa::Context.new` with the same block)
captures `Lipwa.config` and every currently registered gateway class's settings
before running the builder block. Unspecified settings inherit those captured
defaults. `config.gateway(:mpesa) { |mpesa| ... }` overrides only that context's
M-Pesa settings. Provider `timeout` and `logger` take precedence over shared
`default_timeout` and `logger`; otherwise the shared defaults apply.

The snapshot happens when the context is constructed, even if its first gateway
lookup is much later. Subsequent global changes and registrations do not alter
an existing context. Overrides do not change process-wide defaults or other
contexts. Typed overrides are validated during construction.

When the block finishes, configuration is immutable: configuration strings,
arrays, and hashes are copied and frozen. Logger and other service objects retain
their identity rather than being deeply copied or frozen. Gateway runtime state,
such as HTTP clients and OAuth token caches, can still change.

Each context lazily constructs and memoizes its own gateway instances. Repeated
`tenant_context.gateway(:mpesa)` calls return the same instance, distinct from
another context's gateway and from `Lipwa.gateway(:mpesa)`. Built-in provider HTTP
clients, authentication, and token caches belong to those gateway instances.
Pass contexts explicitly; there is no thread-local current tenant.

### Retain one context per tenant

Construct one service object per tenant and retain it across payment calls. Here
`secrets_for` is an application-supplied callable that loads that tenant's secrets
from your credential store during context construction:

{% highlight ruby %}class TenantPayments
  attr_reader :context

  def initialize(tenant_id:, secrets_for:)
    @context = Lipwa.context do |config|
      secrets = secrets_for.call(tenant_id)
      config.default_timeout = 20
      config.gateway(:mpesa) do |mpesa|
        mpesa.env = :production
        mpesa.consumer_key = secrets.fetch(:consumer_key)
        mpesa.consumer_secret = secrets.fetch(:consumer_secret)
        mpesa.shortcode = secrets.fetch(:shortcode)
        mpesa.passkey = secrets.fetch(:passkey)
      end
    end
  end

  def stk_push(**params)
    context.gateway(:mpesa).stk_push(**params)
  end
end

# Retain these services in your application's tenant service registry.
payments_by_tenant = tenant_ids.to_h do |tenant_id|
  [tenant_id, TenantPayments.new(tenant_id: tenant_id, secrets_for: secrets_for)]
end

tenant_context = payments_by_tenant.fetch(tenant_id).context
tenant_context.gateway(:mpesa) # This tenant's memoized gateway
Lipwa.gateway(:mpesa)          # Separate process-wide gateway using boot defaults
{% endhighlight %}

Do not repeatedly mutate `Lipwa::Gateways::Mpesa.configure` per request to switch
tenants: those defaults are shared across requests, and memoized gateways retain
their earlier snapshots. For credential rotation, construct a replacement service
and context with fresh secrets and use it for subsequent calls. Existing contexts
continue using their captured credentials.

Tenant secrets loaded during construction remain covered by Lipwa's HTTP log
redaction for authorization, credentials, tokens, and secret-like fields. This
does not sanitize arbitrary application logs: do not log raw secret hashes or
inspect configuration objects containing credentials.

### Explicit gateway construction and custom authentication

Explicit `config:` and `global_config:` gateway constructor snapshots replace
their respective defaults and are copied and finalized by the gateway.

Custom `auth_strategy` objects are duplicated for each gateway. Stateful custom
strategies should implement `initialize_copy` to isolate nested mutable state,
or supply a zero-argument factory that creates a fresh strategy and token source.
Callable token providers and clocks must not close over shared mutable token
caches. Built-in OAuth clients reset their caches when copied.

<nav class="doc-nav"><a href="{{ '/capabilities/' | relative_url }}">← Capabilities</a><a href="{{ '/webhooks/' | relative_url }}">Webhooks →</a></nav>
