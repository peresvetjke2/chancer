require "rails_helper"

RSpec.describe Team, type: :model do
  it "is valid with valid attributes" do
    expect(build(:team)).to be_valid
  end

  it "is invalid without name" do
    expect(build(:team, name: nil)).not_to be_valid
  end

  it "is invalid without hltv_id" do
    expect(build(:team, hltv_id: nil)).not_to be_valid
  end

  it "is invalid with duplicate hltv_id" do
    create(:team, hltv_id: 42)
    expect(build(:team, hltv_id: 42)).not_to be_valid
  end

  it "stores hltv_rank" do
    team = create(:team, hltv_rank: 5)
    expect(team.hltv_rank).to eq(5)
  end

  it "has many players" do
    team = create(:team)
    player = create(:player, team: team)
    expect(team.players).to include(player)
  end
end
