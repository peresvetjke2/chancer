FactoryBot.define do
  factory :news_item do
    source { "MyString" }
    published_at { "2026-03-31 11:49:34" }
    body { "MyText" }
  end
end
