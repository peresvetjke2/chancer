FactoryBot.define do
  factory :match do
    played_at { Time.current }
    tournament { "ESL Pro League" }
    score { "2:1" }
    association :team1, factory: :team
    association :team2, factory: :team
    winner { nil }
  end
end
