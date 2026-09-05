# frozen_string_literal: true

require "test_helper"

module GatewayTestCapability
  extend Lipwa::Capability
  self.capability_name = :ping

  def ping
    :pong
  end
end

class PlainGateway < Lipwa::Gateway
  configure do |c|
    c.base_url = "https://plain.example.com"
  end
end

class CapableGateway < Lipwa::Gateway
  include GatewayTestCapability

  configure do |c|
    c.base_url = "https://capable.example.com"
    c.timeout = 3
  end
end

class GatewayTest < Minitest::Test
  def test_explicit_snapshots_override_defaults_and_survive_later_changes
    provider = PlainGateway.config.dup
    provider.base_url = +"https://snapshot.example.com"
    provider.timeout = 7
    shared = Lipwa.config.dup
    shared.default_timeout = 19
    gateway = PlainGateway.new(config: provider, global_config: shared)
    provider.base_url.replace("https://changed.example.com")
    provider.timeout = 99
    shared.default_timeout = 99

    assert_equal "https://snapshot.example.com", gateway.http.base_url
    assert_equal 7, gateway.http.timeout
    assert_equal 19, gateway.global_config.default_timeout
  end

  def test_direct_construction_captures_defaults_before_http_is_built
    previous = PlainGateway.config.to_h
    timeout = Lipwa.config.default_timeout
    Lipwa.configure { |config| config.default_timeout = 23 }
    gateway = PlainGateway.new
    PlainGateway.configure { |config| config.base_url = "https://later.example.com" }
    Lipwa.configure { |config| config.default_timeout = 99 }

    assert_equal "https://plain.example.com", gateway.http.base_url
    assert_equal 23, gateway.http.timeout
    assert_equal "https://later.example.com", PlainGateway.new.http.base_url
  ensure
    PlainGateway.config.update(previous)
    Lipwa.config.default_timeout = timeout
  end

  def test_capability_is_false_when_module_not_included
    refute PlainGateway.new.capability?(:ping)
  end

  def test_capability_is_true_when_module_included
    assert CapableGateway.new.capability?(:ping)
  end

  def test_capability_check_accepts_strings_too
    assert CapableGateway.new.capability?("ping")
  end

  def test_included_capability_method_is_actually_callable
    assert_equal :pong, CapableGateway.new.ping
  end

  def test_capabilities_do_not_leak_across_sibling_subclasses
    refute PlainGateway.new.capability?(:ping)
    assert CapableGateway.new.capability?(:ping)
  end

  def test_http_builds_adapter_from_gateway_config
    http = CapableGateway.new.http
    assert_instance_of Lipwa::HttpAdapter, http
    assert_equal "https://capable.example.com", http.base_url
    assert_equal 3, http.timeout
  end

  def test_http_is_memoized_per_instance
    gateway = CapableGateway.new
    assert_same gateway.http, gateway.http
  end

  def test_missing_base_url_raises_configuration_error
    klass = Class.new(Lipwa::Gateway)
    error = assert_raises(Lipwa::ConfigurationError) { klass.new.http }
    assert_match(/base_url/, error.message)
  end

  def test_env_setting_rejects_invalid_values
    assert_raises(Dry::Types::ConstraintError) do
      Class.new(Lipwa::Gateway) { configure { |c| c.env = :staging } }
    end
  end

  def test_capability_module_without_name_raises_on_include
    mod = Module.new { extend Lipwa::Capability }

    error = assert_raises(Lipwa::ConfigurationError) do
      Class.new(Lipwa::Gateway) { include mod }
    end
    assert_match(/capability_name/, error.message)
  end
end
