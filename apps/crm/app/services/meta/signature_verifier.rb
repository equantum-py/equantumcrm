# Checks X-Hub-Signature-256: "sha256=" + hex HMAC-SHA256 of the raw request
# body with the app secret, compared in constant time. The body must be the
# exact bytes Meta sent (request.raw_post), never re-serialized JSON.
module Meta
  class SignatureVerifier
    PREFIX = "sha256=".freeze

    def initialize(secret)
      @secret = secret.to_s
    end

    def valid?(raw_body, header)
      return false if @secret.empty?

      signature = header.to_s
      return false unless signature.start_with?(PREFIX)

      expected = PREFIX + OpenSSL::HMAC.hexdigest("SHA256", @secret, raw_body.to_s)
      ActiveSupport::SecurityUtils.secure_compare(expected, signature)
    end
  end
end
