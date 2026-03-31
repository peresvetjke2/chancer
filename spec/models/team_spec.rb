require "rails_helper"

RSpec.describe Team, type: :model do
  it "is valid with valid attributes" do
    expect(build(:team)).to be_valid
  end

  it "is invalid without name" do
    expect(build(:team, name: nil)).not_to be_valid
  end

  it "has many players" do
    team = create(:team)
    player = create(:player, team: team)
    expect(team.players).to include(player)
  end
end
