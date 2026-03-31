require "rails_helper"

RSpec.describe PlayerStat, type: :model do
  it "is valid with valid attributes" do
    expect(build(:player_stat)).to be_valid
  end

  it "belongs to a player" do
    stat = create(:player_stat)
    expect(stat.player).to be_a(Player)
  end

  it "belongs to a match" do
    stat = create(:player_stat)
    expect(stat.match).to be_a(Match)
  end
end
