FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    password { "test_password_123" }
    locale { "en" }
  end
end
