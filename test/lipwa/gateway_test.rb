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
