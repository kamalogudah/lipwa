# frozen_string_literal: true

require "test_helper"

class GatewaysTestGateway < Lipwa::Gateway
  configure do |c|
    c.base_url = "https://gateways-test.example.com"
  end
end

class GatewaysTest < Minitest::Test
  def test_register_and_resolve_returns_instance_of_gateway_class
    key = :"test_gw_#{__method__}"
    Lipwa::Gateways.register(key, GatewaysTestGateway)

    assert_instance_of GatewaysTestGateway, Lipwa::Gateways[key]
  end

  def test_lipwa_gateway_delegates_to_registry
    key = :"test_gw_#{__method__}"
    Lipwa::Gateways.register(key, GatewaysTestGateway)

    assert_instance_of GatewaysTestGateway, Lipwa.gateway(key)
  end

  def test_resolve_memoizes_the_same_instance
    key = :"test_gw_#{__method__}"
    Lipwa::Gateways.register(key, GatewaysTestGateway)

    assert_same Lipwa::Gateways[key], Lipwa::Gateways[key]
  end

  def test_registering_a_non_gateway_class_raises_configuration_error
    key = :"test_gw_#{__method__}"

    error = assert_raises(Lipwa::ConfigurationError) do
      Lipwa::Gateways.register(key, String)
    end
    assert_match(/must be a subclass of Lipwa::Gateway/, error.message)
  end

  def test_resolving_an_unregistered_key_raises
    assert_raises(Dry::Container::KeyError) do
      Lipwa::Gateways[:"test_gw_#{__method__}_unregistered"]
    end
  end
end
