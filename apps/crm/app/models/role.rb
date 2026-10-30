class Role < ApplicationRecord
  has_many :role_permissions, dependent: :destroy
  has_many :permissions, through: :role_permissions
  has_many :users, dependent: :restrict_with_error

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
end
