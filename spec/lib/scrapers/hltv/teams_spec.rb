require "rails_helper"

RSpec.describe Scrapers::Hltv::Teams do
  let(:html) { File.read(Rails.root.join("spec/fixtures/hltv_teams_ranking.html")) }

  describe "#call" do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_html).and_return(html)
    end

    it "returns an array of hashes with correct keys" do
      result = described_class.call
      expect(result).to be_an(Array)
      expect(result.first.keys).to contain_exactly(:hltv_id, :name, :hltv_rank, :region)
    end

    it "parses team data correctly" do
      result = described_class.call
      expect(result.first).to eq({ hltv_id: 9565, name: "Vitality", hltv_rank: 1, region: "Europe" })
      expect(result.second).to eq({ hltv_id: 4608, name: "Natus Vincere", hltv_rank: 2, region: "Europe" })
    end

    it "returns all teams when no limit given" do
      expect(described_class.call.length).to eq(3)
    end

    it "trims results to the given limit" do
      expect(described_class.call(limit: 2).length).to eq(2)
    end

    it "returns first N teams in rank order" do
      result = described_class.call(limit: 2)
      expect(result.map { |t| t[:hltv_rank] }).to eq([1, 2])
    end
  end

  context "when Selenium times out waiting for ranked teams" do
    before do
      driver = double("driver", navigate: double(to: nil), quit: nil)
      allow(Selenium::WebDriver).to receive(:for).and_return(driver)
      allow_any_instance_of(Selenium::WebDriver::Wait).to receive(:until)
        .and_raise(Selenium::WebDriver::Error::TimeoutError)
    end

    it "raises Scrapers::Hltv::Error" do
      expect { described_class.call }.to raise_error(Scrapers::Hltv::Error, /Timed out/)
    end
  end

  context "when HTML contains no ranked teams" do
    before do
      allow_any_instance_of(described_class).to receive(:fetch_html).and_return("<html><body></body></html>")
    end

    it "returns an empty array" do
      expect(described_class.call).to eq([])
    end
  end
end
