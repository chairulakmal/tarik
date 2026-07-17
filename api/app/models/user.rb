class User < ApplicationRecord
  devise :database_authenticatable, :registerable, :recoverable,
         # :confirmable, # uncommented by bin/setup when email verification is enabled
         :validatable, :jwt_authenticatable,
         jwt_revocation_strategy: JwtDenylist

  has_one :subscription, dependent: :destroy

  validates :locale, inclusion: { in: %w[en ja] }
end
