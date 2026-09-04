# frozen_string_literal: true

require "test_helper"

class PaystackGatewayTest < Minitest::Test
  BASE_URL = "https://paystack.example.com"

  def setup
    Lipwa::Gateways::Paystack.configure do |config|
      config.base_url = BASE_URL
      config.auth_strategy = Lipwa::AuthStrategies::None.new
    end
    @gateway = Lipwa::Gateways::Paystack.new
  end

  def test_registers_card_capabilities
    %i[purchase authorize capture void].each { |name| assert @gateway.capability?(name) }
    assert_instance_of Lipwa::Gateways::Paystack, Lipwa.gateway(:paystack)
  end

  def test_purchase_initializes_a_card_transaction_in_subunits
    request = stub_request(:post, "#{BASE_URL}/transaction/initialize").with do |req|
      body = JSON.parse(req.body)
      body["email"] == "buyer@example.com" && body["amount"] == 10_025 &&
        body["currency"] == "NGN" && body["channels"] == ["card"]
    end.to_return(paystack_response(data: { reference: "ORDER-1", authorization_url: "https://checkout.test" }))

    result = @gateway.purchase(**payment_args(amount: "100.25"))

    assert result.success?
    assert_equal "ORDER-1", result.value!.provider_reference
    assert_requested request
  end

  def test_authorize_uses_the_hosted_card_flow
    request = stub_request(:post, "#{BASE_URL}/transaction/initialize")
              .to_return(paystack_response(data: { reference: "ORDER-1", access_code: "access-code" }))

    result = @gateway.authorize(**payment_args)

    assert result.success?
    assert_requested request
  end

  def test_capture_verifies_a_successful_transaction
    request = stub_request(:get, "#{BASE_URL}/transaction/verify/ORDER-1")
              .to_return(paystack_response(message: "Verification successful",
                                           data: { reference: "ORDER-1", status: "success" }))

    result = @gateway.capture(authorization: "ORDER-1")

    assert result.success?
    assert result.value!.success?
    assert_requested request
  end

  def test_capture_reports_an_incomplete_transaction
    stub_request(:get, "#{BASE_URL}/transaction/verify/ORDER-1")
      .to_return(paystack_response(data: { reference: "ORDER-1", status: "pending" }))

    result = @gateway.capture(authorization: "ORDER-1")

    assert result.success?
    refute result.value!.success?
  end

  def test_void_refunds_the_transaction
    request = stub_request(:post, "#{BASE_URL}/refund")
              .with(body: { transaction: "ORDER-1" }.to_json)
              .to_return(paystack_response(message: "Refund has been queued", data: { status: "pending" }))

    result = @gateway.void(authorization: "ORDER-1")

    assert result.success?
    assert result.value!.success?
    assert_equal "ORDER-1", result.value!.provider_reference
    assert_requested request
  end

  def test_requires_an_email_address
    result = @gateway.purchase(**payment_args.merge(billing_address: { phone_number: "+2348000000000" }))

    assert result.failure?
    assert_match(/email_address is required/, result.failure.message)
  end

  private

  def payment_args(amount: 100)
    {
      amount: Lipwa::Money.new(amount: amount, currency: "NGN"), reference: "ORDER-1",
      description: "Order one", callback_url: "https://merchant.example/callback",
      notification_id: "merchant-webhook", billing_address: { email_address: "buyer@example.com" }
    }
  end

  def paystack_response(message: "Authorization URL created", data: {})
    { status: 200, headers: { "Content-Type" => "application/json" },
      body: { status: true, message: message, data: data }.to_json }
  end
end
