require "rails_helper"

RSpec.describe Match, type: :model do
  it "is valid with valid attributes" do
    expect(build(:match)).to be_valid
  end

  it "is invalid without played_at" do
    expect(build(:match, played_at: nil)).not_to be_valid
  end

  it "belongs to team1" do
    match = create(:match)
    expect(match.team1).to be_a(Team)
  end

  it "belongs to team2" do
    match = create(:match)
    expect(match.team2).to be_a(Team)
  end

  it "allows winner to be nil" do
    expect(build(:match, winner: nil)).to be_valid
  end

  it "accepts a winner" do
    team = create(:team)
    match = create(:match, winner: team)
    expect(match.winner).to eq(team)
  end
end
