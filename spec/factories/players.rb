FactoryBot.define do
  factory :player do
    name { "Player One" }
    role { "rifler" }
    association :team
  end
end
