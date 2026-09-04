# frozen_string_literal: true

require "test_helper"

class FlutterwaveGatewayTest < Minitest::Test
  BASE_URL = "https://flutterwave.example.com"

  def setup
    Lipwa::Gateways::Flutterwave.configure do |config|
      config.base_url = BASE_URL
      config.auth_strategy = Lipwa::AuthStrategies::None.new
      config.encryption_key = "123456789012345678901234"
    end
    @gateway = Lipwa::Gateways::Flutterwave.new
  end

  def test_registers_card_capabilities
    %i[purchase authorize capture void].each { |name| assert @gateway.capability?(name) }
    assert_instance_of Lipwa::Gateways::Flutterwave, Lipwa.gateway(:flutterwave)
  end

  def test_purchase_creates_hosted_card_payment
    request = stub_request(:post, "#{BASE_URL}/v3/payments").with do |req|
      body = JSON.parse(req.body)
      body["tx_ref"] == "ORDER-1" && body["payment_options"] == "card" &&
        body.dig("customer", "email") == "buyer@example.com"
    end.to_return(json_response(data: { link: "https://checkout.flutterwave.com/1" }))

    result = @gateway.purchase(**payment_args)

    assert result.success?
    assert_equal "ORDER-1", result.value!.provider_reference
    assert_requested request
  end

  def test_authorize_creates_preauthorized_card_charge
    request = stub_request(:post, "#{BASE_URL}/v3/charges?type=card").with do |req|
      body = JSON.parse(req.body)
      body.keys == ["client"] && !body["client"].empty?
    end.to_return(json_response(data: { flw_ref: "FLW-PREAUTH-1", status: "pending-capture" }))

    result = @gateway.authorize(**payment_args.merge(card_args))

    assert result.success?
    assert_equal "FLW-PREAUTH-1", result.value!.provider_reference
    assert_requested request
  end

  def test_capture_and_void_preauthorized_charge
    capture_request = stub_request(:post, "#{BASE_URL}/v3/charges/FLW-PREAUTH-1/capture")
                      .with { |req| BigDecimal(JSON.parse(req.body)["amount"].to_s) == 40 }
                      .to_return(json_response(message: "Charge captured", data: { flw_ref: "FLW-PREAUTH-1" }))
    void_request = stub_request(:post, "#{BASE_URL}/v3/charges/FLW-PREAUTH-2/void")
                   .with(body: {}.to_json)
                   .to_return(json_response(message: "Charge voided", data: { flw_ref: "FLW-PREAUTH-2" }))

    capture = @gateway.capture(authorization: "FLW-PREAUTH-1", amount: money(40))
    void = @gateway.void(authorization: "FLW-PREAUTH-2")

    assert capture.success?
    assert void.success?
    assert_requested capture_request
    assert_requested void_request
  end

  private

  def payment_args
    {
      amount: money(100), reference: "ORDER-1", description: "Order one",
      callback_url: "https://merchant.example/callback", notification_id: "unused-by-flutterwave",
      billing_address: { email_address: "buyer@example.com", first_name: "Ada", last_name: "Lovelace" }
    }
  end

  def card_args
    { card_number: "4556052704172643", cvv: "899", expiry_month: "01", expiry_year: "31" }
  end

  def money(amount) = Lipwa::Money.new(amount: amount, currency: "NGN")

  def json_response(message: "Successful", data: {})
    { status: 200, headers: { "Content-Type" => "application/json" },
      body: { status: "success", message: message, data: data }.to_json }
  end
end
