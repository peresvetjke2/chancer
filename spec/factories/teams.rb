FactoryBot.define do
  factory :team do
    sequence(:hltv_id) { |n| n }
    name { "Natus Vincere" }
    region { "CIS" }
    hltv_rank { 1 }
  end
end
