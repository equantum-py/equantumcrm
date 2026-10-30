class Current < ActiveSupport::CurrentAttributes
  attribute :session, :api_client, :ip_address, :request_id
  delegate :user, to: :session, allow_nil: true
end
