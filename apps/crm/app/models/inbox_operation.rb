# Stored result of an inbox write, keyed by the operation_id the form carried
# (plan r2, P3). An identical retry returns this result instead of applying
# again; the same id with a different request is rejected.
class InboxOperation < ApplicationRecord
  RETENTION = 7.days

  belongs_to :target, polymorphic: true
  belongs_to :actor, class_name: "User"

  validates :operation_id, presence: true, uniqueness: true
  validates :action, :request_sha256, :response_status, presence: true

  scope :expired, -> { where(created_at: ...RETENTION.ago) }

  def self.fingerprint(action, params)
    Digest::SHA256.hexdigest(JSON.generate([ action.to_s, params.to_h.sort.to_h ]))
  end

  def replay_of?(actor:, action:, request_sha256:)
    actor_id == actor.id && self.action == action.to_s && self.request_sha256 == request_sha256
  end
end
