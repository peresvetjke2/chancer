FactoryBot.define do
  factory :team do
    sequence(:hltv_id) { |n| n }
    name { "Natus Vincere" }
    region { "CIS" }
    hltv_rank { 1 }
  end

  factory :pandascore_team, class: "Team" do
    sequence(:pandascore_id) { |n| n }
    sequence(:pandascore_rank) { |n| n }
    name { "Team Liquid" }
  end
end
