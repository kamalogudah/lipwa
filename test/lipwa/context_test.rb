# frozen_string_literal: true

require "test_helper"

class ContextTest < Minitest::Test
  def setup
    @timeout = Lipwa.config.default_timeout
    @mpesa = Lipwa::Gateways::Mpesa.config.to_h
  end

  def teardown
    Lipwa.config.default_timeout = @timeout
    Lipwa::Gateways::Mpesa.config.update(@mpesa)
  end

  def test_public_builder_combines_global_and_gateway_overrides
    context = Lipwa.context do |config|
      config.default_timeout = 20
      config.gateway(:mpesa) do |mpesa|
        mpesa.consumer_key = "tenant-key"
        mpesa.consumer_secret = "tenant-secret"
        mpesa.shortcode = "123456"
        mpesa.passkey = "tenant-passkey"
      end
    end

    gateway = context.gateway(:mpesa)
    assert_instance_of Lipwa::Context, context
    assert_instance_of Lipwa::Gateways::Mpesa, gateway
    assert_equal 20, gateway.http.timeout
    assert_equal "tenant-key", gateway.config.consumer_key
    assert_equal :sandbox, gateway.config.env
    assert_equal 5, gateway.config.open_timeout
    assert_equal @timeout, Lipwa.config.default_timeout
    assert_equal @mpesa, Lipwa::Gateways::Mpesa.config.to_h
    assert_same gateway, context.gateway("mpesa")
    refute_same gateway, Lipwa.gateway(:mpesa)
  end

  def test_snapshots_existing_values_before_overrides_and_later_reconfiguration
    Lipwa.config.default_timeout = 17
    Lipwa::Gateways::Mpesa.config.shortcode = +"original"
    context = Lipwa::Context.new
    Lipwa.config.default_timeout = 99
    Lipwa::Gateways::Mpesa.config.shortcode.replace("changed")
    Lipwa::Gateways::Mpesa.config.env = :production

    assert_equal 17, context.config.default_timeout
    assert_equal "original", context.gateway(:mpesa).config.shortcode
    assert_equal :sandbox, context.gateway(:mpesa).config.env
    assert_equal 99, Lipwa.context.config.default_timeout
  end

  def test_contexts_and_mutable_overrides_are_isolated
    shortcode = +"tenant"
    first = Lipwa.context { |config| config.gateway(:mpesa) { |mpesa| mpesa.shortcode = shortcode } }
    second = Lipwa.context
    shortcode.replace("changed")

    assert_equal "tenant", first.gateway(:mpesa).config.shortcode
    assert_equal @mpesa, second.gateway(:mpesa).config.to_h
    refute_same first.gateway(:mpesa), second.gateway(:mpesa)
  end

  def test_configuration_is_frozen_after_the_block
    builder = nil
    context = Lipwa.context { |config| builder = config }

    assert_predicate context.config, :frozen?
    assert_predicate context.gateway(:mpesa).config, :frozen?
    assert_raises(Dry::Configurable::FrozenConfigError) { builder.default_timeout = 30 }
    assert_raises(Dry::Configurable::FrozenConfigError) { builder.gateway(:mpesa).env = :production }
  end

  def test_invalid_overrides_fail_during_construction
    assert_raises(Dry::Types::ConstraintError) do
      Lipwa.context { |config| config.gateway(:mpesa) { |mpesa| mpesa.env = :staging } }
    end
    assert_raises(NoMethodError) { Lipwa.context { |config| config.unknown_setting = true } }
    assert_equal @mpesa, Lipwa::Gateways::Mpesa.config.to_h
  end

  def test_setting_constructors_are_preserved_without_reprocessing_snapshot_values
    klass = Class.new(Lipwa::Gateway) do
      setting :label, constructor: ->(value) { "constructed:#{value}" }
    end
    klass.config.label = "global"
    name = :context_constructor_test
    Lipwa::Gateways.register(name, klass)

    assert_equal "constructed:global", Lipwa.context.gateway(name).config.label
    context = Lipwa.context { |config| config.gateway(name) { |gateway| gateway.label = "tenant" } }
    assert_equal "constructed:tenant", context.gateway(name).config.label
    assert_equal "constructed:global", klass.config.label
  end

  def test_requests_use_context_settings_even_when_built_after_global_changes
    klass = Class.new(Lipwa::Gateway) do
      include Lipwa::Capabilities::C2B
      setting :shortcode, default: "global"
      configure { |config| config.base_url = "https://context.example.com" }
    end
    Lipwa::Gateways.register(:context_requests, klass)
    Lipwa.config.default_timeout = 18
    context = Lipwa.context do |config|
      config.gateway(:context_requests) { |gateway| gateway.shortcode = "tenant" }
    end
    klass.config.shortcode = "changed"
    klass.config.base_url = "https://changed.example.com"
    Lipwa.config.default_timeout = 99
    request = stub_request(:post, "https://context.example.com/mpesa/c2b/v1/registerurl")
              .with { |req| JSON.parse(req.body)["ShortCode"] == "tenant" }
              .to_return(status: 200, headers: { "Content-Type" => "application/json" },
                         body: { ResponseCode: "0" }.to_json)

    gateway = context.gateway(:context_requests)
    result = gateway.register_urls(validation_url: "https://example.com/validate",
                                   confirmation_url: "https://example.com/confirm")

    assert result.success?
    assert_equal 18, gateway.http.timeout
    assert_requested request
  end

  def test_unregistered_names_keep_registry_errors
    context = Lipwa.context
    assert_raises(Dry::Container::KeyError) { context.gateway(:unknown_context_gateway) }
    assert_raises(Dry::Container::KeyError) do
      Lipwa.context { |config| config.gateway(:unknown_context_gateway) {} }
    end
  end
end
