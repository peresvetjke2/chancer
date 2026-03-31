FactoryBot.define do
  factory :player_stat do
    kills { 20 }
    deaths { 15 }
    rating { 1.10 }
    association :player
    association :match
  end
end
