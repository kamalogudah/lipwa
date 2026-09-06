# frozen_string_literal: true

require "test_helper"
require "logger"
require "stringio"

class ProviderContextIsolationTest < Minitest::Test
  PROVIDERS = %i[mpesa coop_bank jenga pesapal flutterwave paystack].freeze
  OAUTH_PROVIDERS = %i[mpesa coop_bank jenga pesapal].freeze

  def setup
    @private_key = OpenSSL::PKey::RSA.new(1024).to_pem
  end

  def test_every_provider_builds_context_owned_http_and_auth_objects
    first = build_context("alpha", env: :sandbox, timeout: 3)
    second = build_context("bravo", env: :production, timeout: 7)

    PROVIDERS.each do |name|
      first_gateway = first.fetch(:context).gateway(name)
      second_gateway = second.fetch(:context).gateway(name)

      assert_same first_gateway, first.fetch(:context).gateway(name)
      refute_same first_gateway, second_gateway
      refute_same first_gateway.http, second_gateway.http
      refute_same first_gateway.http.auth_strategy, second_gateway.http.auth_strategy
      assert_equal "https://#{name}-alpha.example.test", first_gateway.http.base_url
      assert_equal "https://#{name}-bravo.example.test", second_gateway.http.base_url
      assert_equal :sandbox, first_gateway.config.env
      assert_equal :production, second_gateway.config.env
      assert_equal 3, first_gateway.http.timeout
      assert_equal 7, second_gateway.http.timeout
      assert_equal 1, first_gateway.http.open_timeout
      assert_equal 2, second_gateway.http.open_timeout
      assert_same first.fetch(:logger), first_gateway.http.logger
      assert_same second.fetch(:logger), second_gateway.http.logger
    end

    OAUTH_PROVIDERS.each do |name|
      first_gateway = first.fetch(:context).gateway(name)
      second_gateway = second.fetch(:context).gateway(name)
      first_client = token_client(first_gateway)
      second_client = token_client(second_gateway)

      refute_same first_client, second_client
      assert_same first_gateway.config.clock, first_client.instance_variable_get(:@clock)
      assert_same second_gateway.config.clock, second_client.instance_variable_get(:@clock)
      first_client.instance_variable_set(:@token, "alpha-cached-token")
      assert_nil second_client.instance_variable_get(:@token)
    end
  end

  def test_auth_overrides_are_copied_and_isolated_for_mpesa
    first = build_mpesa_auth_override_context("alpha")
    second = build_mpesa_auth_override_context("bravo")
    first_gateway = first.gateway(:mpesa)
    second_gateway = second.gateway(:mpesa)

    assert_instance_of Lipwa::AuthStrategies::ApiKey, first_gateway.http.auth_strategy
    refute_same first_gateway.http.auth_strategy, second_gateway.http.auth_strategy
    assert_equal "alpha-override", applied_key(first_gateway.http.auth_strategy)
    assert_equal "bravo-override", applied_key(second_gateway.http.auth_strategy)
  end

  def test_concurrent_requests_cannot_cross_tenant_credentials
    tenants = %w[alpha bravo]
    contexts = tenants.to_h do |tenant|
      [tenant, build_paystack_context(tenant)]
    end
    ready = Queue.new
    release = Queue.new

    tenants.each do |tenant|
      stub_request(:get, "https://paystack-#{tenant}.example.test/probe")
        .with(headers: { "Authorization" => "Bearer #{tenant}-secret-key" })
        .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                   body: { tenant: tenant }.to_json)
    end

    threads = tenants.map do |tenant|
      Thread.new do
        ready << tenant
        release.pop
        response = contexts.fetch(tenant).fetch(:context).gateway(:paystack).http.get("/probe")
        [tenant, response.body.fetch("tenant")]
      end
    end

    tenants.size.times { ready.pop }
    tenants.size.times { release << true }
    threads.each { |thread| assert thread.join(5), "concurrent provider request deadlocked" }
    assert_equal tenants.sort, threads.map(&:value).map(&:last).sort

    contexts.each_value do |entry|
      output = entry.fetch(:output).string
      tenants.each { |tenant| refute_includes output, "#{tenant}-secret-key" }
    end
  end

  def test_credentials_do_not_appear_in_gateway_adapter_or_auth_inspection
    entry = build_context("diagnostic", env: :sandbox, timeout: 4)

    PROVIDERS.each do |name|
      gateway = entry.fetch(:context).gateway(name)
      inspected = [gateway, gateway.config, gateway.http, gateway.http.auth_strategy]
      inspected << token_client(gateway) if OAUTH_PROVIDERS.include?(name)

      inspected.each do |object|
        refute_includes object.inspect, "diagnostic-secret"
        refute_includes object.inspect, "diagnostic-key"
        refute_includes object.inspect, "diagnostic-passkey"
      end
    end
  end

  private

  def build_context(label, env:, timeout:)
    output = StringIO.new
    logger = Logger.new(output)
    clock = -> { Time.at(label == "alpha" ? 100 : 200) }
    context = Lipwa.context do |config|
      configure_providers(config, label, env, timeout, logger, clock)
    end
    { context: context, logger: logger, output: output }
  end

  def configure_providers(builder, label, env, timeout, logger, clock)
    PROVIDERS.each do |name|
      builder.gateway(name) do |provider|
        provider.env = env
        provider.base_url = "https://#{name}-#{label}.example.test"
        provider.timeout = timeout
        provider.open_timeout = label == "alpha" ? 1 : 2
        provider.logger = logger
      end
    end

    builder.gateway(:mpesa) do |provider|
      provider.consumer_key = "#{label}-key"
      provider.consumer_secret = "#{label}-secret"
      provider.shortcode = "#{label}-shortcode"
      provider.passkey = "#{label}-passkey"
      provider.clock = clock
    end
    builder.gateway(:coop_bank) do |provider|
      provider.api_key = "#{label}-key"
      provider.api_secret = "#{label}-secret"
      provider.token_url = "https://coop-#{label}.example.test/token"
      provider.clock = clock
    end
    builder.gateway(:jenga) do |provider|
      provider.api_key = "#{label}-key"
      provider.merchant_code = "#{label}-merchant"
      provider.consumer_secret = "#{label}-secret"
      provider.private_key = @private_key
      provider.source_account = "#{label}-account"
      provider.source_name = "#{label}-name"
      provider.token_url = "https://jenga-#{label}.example.test/token"
      provider.clock = clock
    end
    builder.gateway(:pesapal) do |provider|
      provider.consumer_key = "#{label}-key"
      provider.consumer_secret = "#{label}-secret"
      provider.clock = clock
    end
    builder.gateway(:flutterwave) { |provider| provider.secret_key = "#{label}-secret-key" }
    builder.gateway(:paystack) { |provider| provider.secret_key = "#{label}-secret-key" }
  end

  def build_mpesa_auth_override_context(label)
    Lipwa.context do |config|
      config.gateway(:mpesa) do |provider|
        provider.base_url = "https://mpesa-#{label}.example.test"
        provider.shortcode = "#{label}-shortcode"
        provider.passkey = "#{label}-passkey"
        provider.auth_strategy = Lipwa::AuthStrategies::ApiKey.new("#{label}-override")
      end
    end
  end

  def build_paystack_context(tenant)
    output = StringIO.new
    logger = Logger.new(output)
    context = Lipwa.context do |config|
      config.gateway(:paystack) do |provider|
        provider.base_url = "https://paystack-#{tenant}.example.test"
        provider.secret_key = "#{tenant}-secret-key"
        provider.logger = logger
      end
    end
    { context: context, output: output }
  end

  def token_client(gateway)
    gateway.http.auth_strategy.instance_variable_get(:@token_provider)
  end

  def applied_key(strategy)
    env = Faraday::Env.new
    env.request_headers = Faraday::Utils::Headers.new
    strategy.apply(env)
    env.request_headers.fetch("X-Api-Key")
  end
end
