# frozen_string_literal: true

require "test_helper"

class ErrorsTest < Minitest::Test
  def test_configuration_error_is_a_lipwa_error
    assert_kind_of Lipwa::Error, Lipwa::ConfigurationError.new
  end

  def test_unsupported_capability_error_is_a_lipwa_error
    assert_kind_of Lipwa::Error, Lipwa::UnsupportedCapabilityError.new
  end

  def test_gateway_error_exposes_code_and_raw
    error = Lipwa::GatewayError.new("boom", code: "500", raw: { foo: "bar" })
    assert_equal "boom", error.message
    assert_equal "500", error.code
    assert_equal({ foo: "bar" }, error.raw)
  end

  FakeErrors = Struct.new(:errors_hash) do
    def to_h
      errors_hash
    end
  end
  FakeValidationResult = Struct.new(:errors)

  def test_validation_error_exposes_validation_result
    result = FakeValidationResult.new(FakeErrors.new({ phone_number: ["is missing"] }))

    error = Lipwa::ValidationError.new(result)
    assert_equal result, error.validation_result
    assert_match(/phone_number/, error.message)
  end
end
