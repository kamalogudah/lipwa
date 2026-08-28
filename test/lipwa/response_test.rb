# frozen_string_literal: true

require "test_helper"

class ResponseTest < Minitest::Test
  def test_success_predicate
    response = Lipwa::Response.new(success: true, provider_reference: "ref-1")
    assert response.success?
  end

  def test_optional_fields_default_to_nil
    response = Lipwa::Response.new(success: false, provider_reference: nil)
    assert_nil response.message
    assert_nil response.code
    assert_nil response.raw
  end
end
