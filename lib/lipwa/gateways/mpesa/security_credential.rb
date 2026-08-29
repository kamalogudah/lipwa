# frozen_string_literal: true

require "base64"
require "openssl"
require_relative "../../errors"

module Lipwa
  module Gateways
    class Mpesa
      # Encrypts the B2C/B2B initiator password into the SecurityCredential
      # Daraja expects: RSA-encrypted (PKCS#1 v1.5 padding) with Safaricom's
      # public certificate, then base64-encoded. Sandbox and production use
      # different certificates — download the right one from the Daraja
      # portal (Test Credentials page for sandbox, the app's production
      # cert for production) and pass its PEM/DER content as
      # `security_credential_cert:` on the Mpesa gateway config. Daraja is
      # the only party that ever decrypts this, so there's nothing to
      # verify locally beyond "does this cert parse and encrypt".
      module SecurityCredential
        def self.encrypt(password, cert:)
          certificate = OpenSSL::X509::Certificate.new(cert)
          encrypted = certificate.public_key.public_encrypt(password, OpenSSL::PKey::RSA::PKCS1_PADDING)
          Base64.strict_encode64(encrypted)
        rescue OpenSSL::X509::CertificateError, OpenSSL::PKey::PKeyError => e
          raise Lipwa::ConfigurationError, "invalid security_credential_cert: #{e.message}"
        end
      end
    end
  end
end
