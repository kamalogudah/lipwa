# frozen_string_literal: true

require "test_helper"

module Lipwa
  module Gateways
    class Mpesa
      class SecurityCredentialTest < Minitest::Test
        def test_encrypt_returns_a_non_empty_base64_string
          result = SecurityCredential.encrypt("test-initiator-password", cert: TEST_MPESA_CERT)

          refute_empty result
          assert_equal result, Base64.strict_encode64(Base64.strict_decode64(result))
        end

        def test_encrypt_raises_configuration_error_for_an_invalid_cert
          error = assert_raises(Lipwa::ConfigurationError) do
            SecurityCredential.encrypt("test-initiator-password", cert: "not a certificate")
          end

          assert_match(/invalid security_credential_cert/, error.message)
        end
      end
    end
  end
end
