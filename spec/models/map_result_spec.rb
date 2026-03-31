require "rails_helper"

RSpec.describe MapResult, type: :model do
  it "is valid with valid attributes" do
    expect(build(:map_result)).to be_valid
  end

  it "is invalid without map_name" do
    expect(build(:map_result, map_name: nil)).not_to be_valid
  end

  it "belongs to a match" do
    map_result = create(:map_result)
    expect(map_result.match).to be_a(Match)
  end
end
