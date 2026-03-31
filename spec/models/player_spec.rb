require "rails_helper"

RSpec.describe Player, type: :model do
  it "is valid with valid attributes" do
    expect(build(:player)).to be_valid
  end

  it "is invalid without name" do
    expect(build(:player, name: nil)).not_to be_valid
  end

  it "belongs to a team" do
    team = create(:team)
    player = create(:player, team: team)
    expect(player.team).to eq(team)
  end
end
