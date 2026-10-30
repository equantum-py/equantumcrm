# Stored response for an Idempotency-Key, so a retried request gets the same
# answer and a reused key with a different body is rejected.
class IngestionRequest < ApplicationRecord
  belongs_to :api_client
  belongs_to :lead, optional: true

  validates :idempotency_key, presence: true, length: { in: 8..128 }
  validates :request_sha256, :response_status, presence: true
end
