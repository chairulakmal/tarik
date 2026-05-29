class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :validatable, :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  has_one :subscription, dependent: :destroy

  validates :locale, inclusion: { in: %w[en ja] }
end
