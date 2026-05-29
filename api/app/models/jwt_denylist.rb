class JwtDenylist < ApplicationRecord
  include Devise::JWT::RevocationStrategies::Denylist

  # devise-jwt expects the singular table name "jwt_denylist", not the Rails
  # default plural "jwt_denylists". Keep this explicit override.
  self.table_name = "jwt_denylist"
end
