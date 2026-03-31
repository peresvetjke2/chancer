FactoryBot.define do
  factory :map_result do
    map_name { "Mirage" }
    score { "16:14" }
    association :match
  end
end
