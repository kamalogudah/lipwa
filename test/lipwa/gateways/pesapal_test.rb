# frozen_string_literal: true

require "test_helper"

class PesapalGatewayTest < Minitest::Test
  BASE_URL = "https://pesapal.example.com"

  def setup
    Lipwa::Gateways::Pesapal.configure do |config|
      config.base_url = BASE_URL
      config.auth_strategy = Lipwa::AuthStrategies::None.new
    end
    @gateway = Lipwa::Gateways::Pesapal.new
  end

  def test_registers_card_capabilities
    %i[purchase authorize capture void].each { |name| assert @gateway.capability?(name) }
    assert_instance_of Lipwa::Gateways::Pesapal, Lipwa.gateway(:pesapal)
  end

  def test_purchase_submits_a_hosted_checkout_order
    request = stub_request(:post, "#{BASE_URL}/api/Transactions/SubmitOrderRequest")
              .with do |req|
                body = JSON.parse(req.body)
                body["id"] == "ORDER-1" && body["amount"].to_d == BigDecimal("100") &&
                  body["currency"] == "KES" && body.dig("billing_address", "email_address") == "buyer@example.com"
              end
              .to_return(json_response(order_tracking_id: "TRACK-1", redirect_url: "https://pay.example/1"))

    result = @gateway.purchase(**payment_args)

    assert result.success?
    assert_equal "TRACK-1", result.value!.provider_reference
    assert_equal "https://pay.example/1", result.value!.raw["redirect_url"]
    assert_requested request
  end

  def test_capture_verifies_completion_and_void_cancels_order
    status = stub_request(:get, "#{BASE_URL}/api/Transactions/GetTransactionStatus")
             .with(query: { orderTrackingId: "TRACK-1" })
             .to_return(json_response(payment_status_description: "Completed", status_code: 1,
                                      confirmation_code: "CONFIRM-1"))
    cancel = stub_request(:post, "#{BASE_URL}/api/Transactions/CancelOrder")
             .with(body: { order_tracking_id: "TRACK-2" }.to_json)
             .to_return(json_response(message: "Order successfully cancelled."))

    capture = @gateway.capture(authorization: "TRACK-1")
    void = @gateway.void(authorization: "TRACK-2")

    assert capture.success?
    assert_equal "CONFIRM-1", capture.value!.provider_reference
    assert void.success?
    assert_equal "TRACK-2", void.value!.provider_reference
    assert_requested status
    assert_requested cancel
  end

  def test_rejects_invalid_payment_before_network_call
    result = @gateway.purchase(**payment_args.merge(reference: "bad reference"))

    assert result.failure?
    assert_instance_of Lipwa::ValidationError, result.failure
  end

  private

  def payment_args
    {
      amount: Lipwa::Money.new(amount: 100, currency: "KES"), reference: "ORDER-1",
      description: "Order one", callback_url: "https://merchant.example/callback",
      notification_id: "notification-id", billing_address: { email_address: "buyer@example.com" }
    }
  end

  def json_response(body)
    { status: 200, headers: { "Content-Type" => "application/json" }, body: body.merge(status: "200").to_json }
  end
end
