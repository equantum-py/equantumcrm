# An internal note on an inbox item ("Solo para el equipo"). Never sent to the
# customer; its text is encrypted and kept out of the audit log.
class InboxNote < ApplicationRecord
  include Auditable

  encrypts :body

  belongs_to :inbox_item
  belongs_to :author, class_name: "User"

  validates :body, presence: true, length: { maximum: 2000 }
end
