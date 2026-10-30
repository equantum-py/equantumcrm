class Session < ApplicationRecord
  TTL = 14.days

  belongs_to :user

  scope :alive, -> { where(created_at: TTL.ago..) }
end
