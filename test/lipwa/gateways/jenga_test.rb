# frozen_string_literal: true

require "test_helper"

class JengaGatewayTest < Minitest::Test
  BASE_URL = "https://jenga.example.com"

  def setup
    Lipwa::Gateways::Jenga.configure do |config|
      config.base_url = BASE_URL
      config.auth_strategy = Lipwa::AuthStrategies::None.new
      config.source_account = "0011547896523"
      config.source_name = "Lipwa Merchant"
      config.country_code = "KE"
      config.partner_id = "PARTNER-1"
      config.clock = -> { Date.new(2026, 9, 4) }
    end
    @gateway = Lipwa::Gateways::Jenga.new
  end

  def test_registers_bank_transfer_and_disbursement_capabilities
    assert @gateway.capability?(:bank_transfer)
    assert @gateway.capability?(:disbursement)
    assert_instance_of Lipwa::Gateways::Jenga, Lipwa.gateway(:jenga)
  end

  def test_sends_internal_pesalink_rtgs_and_swift_transfers
    expected_paths = {
      internal: "internalBankTransfer",
      pesalink: "pesalinkacc",
      rtgs: "rtgs",
      swift: "swift"
    }

    expected_paths.each do |rail, path|
      request = stub_request(:post, "#{BASE_URL}/transaction-api/v3.0/remittance/#{path}")
                .with { |req| transfer_body_matches?(req, rail) }
                .to_return(json_response(transactionId: "JENGA-#{rail}"))

      result = @gateway.transfer(**transfer_args(rail))

      assert result.success?, result.inspect
      assert_equal "JENGA-#{rail}", result.value!.provider_reference
      assert_requested request
    end
  end

  def test_pays_a_bill
    request = stub_request(:post, "#{BASE_URL}/transaction-api/v3.0/bills/pay")
              .with do |req|
                body = JSON.parse(req.body)
                body.dig("biller", "billerCode") == "KPLC" &&
                  body.dig("bill", "reference") == "ACC-9" &&
                  body.dig("bill", "amount") == "100.00" &&
                  body.dig("payer", "reference") == "INV-9" &&
                  body["partnerId"] == "PARTNER-1"
              end
              .to_return(json_response(transactionId: "BILL-1"))

    result = @gateway.transfer(**transfer_args(:bill_payment).merge(
      destination_account: "ACC-9", reference: "INV-9", biller_code: "KPLC"
    ))

    assert result.success?
    assert_requested request
  end

  def test_queries_balance_and_full_statement
    balance_request = stub_request(
      :get, "#{BASE_URL}/account-api/v3.0/accounts/balances/KE/0011547896523"
    ).to_return(json_response(reference: "BAL-1"))
    statement_request = stub_request(:post, "#{BASE_URL}/account-api/v3.0/accounts/fullStatement")
                        .with do |req|
                          JSON.parse(req.body) == {
                            "countryCode" => "KE",
                            "accountNumber" => "0011547896523",
                            "fromDate" => "2026-09-01",
                            "toDate" => "2026-09-04"
                          }
                        end
                        .to_return(json_response(reference: "STM-1"))

    assert @gateway.balance(account_number: "0011547896523").success?
    result = @gateway.statement(
      account_number: "0011547896523",
      from_date: Date.new(2026, 9, 1),
      to_date: Date.new(2026, 9, 4)
    )

    assert result.success?
    assert_requested balance_request
    assert_requested statement_request
  end

  def test_disburses_to_a_mobile_wallet
    request = stub_request(:post, "#{BASE_URL}/transaction-api/v3.0/remittance/sendmobile")
              .with do |req|
                body = JSON.parse(req.body)
                body.dig("destination", "mobileNumber") == "254712345678" &&
                  body.dig("destination", "walletName") == "Mpesa" &&
                  body.dig("transfer", "amount") == "100.00"
              end
              .to_return(json_response(transactionId: "MOBILE-1"))

    result = @gateway.disburse(
      command_id: "SalaryPayment",
      amount: money,
      party_b: "254712345678",
      remarks: "Payout",
      result_url: "https://merchant.example.com/result",
      queue_timeout_url: "https://merchant.example.com/timeout",
      occasion: "PAYOUT-1"
    )

    assert result.success?
    assert_equal "MOBILE-1", result.value!.provider_reference
    assert_requested request
  end

  def test_fetches_forex_rates
    request = stub_request(:post, "#{BASE_URL}/transaction-api/v3.0/foreignexchangerates")
              .with(body: {
                countryCode: "KE", currencyCode: "KES", amount: "100.00", toCurrency: "USD"
              }.to_json)
              .to_return(json_response(reference: "FX-1"))

    result = @gateway.forex_rates(currency_code: "KES", amount: 100, to_currency: "USD")

    assert result.success?
    assert_requested request
  end

  def test_builds_endpoint_specific_signature_payloads
    assert_equal "100.00KESREF-1Lipwa Merchant0011547896523",
                 signature_for("/transaction-api/v3.0/remittance/pesalinkacc", transfer_body(:pesalink))
    assert_equal "REF-12026-09-040011547896523999999100.00",
                 signature_for("/transaction-api/v3.0/remittance/rtgs", transfer_body(:rtgs))
    assert_equal "KE0011547896523",
                 signature_for("/account-api/v3.0/accounts/balances/KE/0011547896523", nil)
  end

  private

  def money = Lipwa::Money.new(amount: 100, currency: "KES")

  def transfer_args(rail)
    {
      rail: rail,
      amount: money,
      source_account: "0011547896523",
      destination_account: "999999",
      destination_bank_code: "68",
      destination_name: "Lipwa Merchant",
      reference: "REF-1",
      narration: "Transfer"
    }
  end

  def transfer_body(rail)
    @gateway.send(:bank_transfer_body, transfer_args(rail))
  end

  def transfer_body_matches?(request, rail)
    body = JSON.parse(request.body)
    body.dig("source", "accountNumber") == "0011547896523" &&
      body.dig("destination", "accountNumber") == "999999" &&
      body.dig("transfer", "type") == Lipwa::Gateways::Jenga::TRANSFER_TYPES.fetch(rail) &&
      body.dig("transfer", "amount") == "100.00"
  end

  def signature_for(path, body)
    env = Faraday::Env.new
    env.url = URI("#{BASE_URL}#{path}")
    env.body = body&.to_json
    @gateway.send(:signature_payload, env)
  end

  def json_response(data)
    {
      status: 200,
      headers: { "Content-Type" => "application/json" },
      body: { status: true, code: "0", data: data }.to_json
    }
  end
end
