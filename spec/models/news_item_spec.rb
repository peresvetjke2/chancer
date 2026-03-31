require "rails_helper"

RSpec.describe NewsItem, type: :model do
  it "is valid with valid attributes" do
    expect(build(:news_item)).to be_valid
  end

  it "is invalid without source" do
    expect(build(:news_item, source: nil)).not_to be_valid
  end
end
