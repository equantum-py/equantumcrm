require "test_helper"

# Same vectors are checked by Prospect AI (services/prospect-ai/tests).
class FingerprintContractTest < ActiveSupport::TestCase
  VECTORS = JSON.parse(File.read(Rails.root.join("../../contracts/fingerprint-vectors.json")))

  VECTORS["cases"].each do |vector|
    test "fingerprint vector: #{vector['name']}" do
      assert_equal vector["expected"], Lead.fingerprint_for(source_key: vector["source"], url: vector["url"], text: vector["text"])
    end
  end
end
