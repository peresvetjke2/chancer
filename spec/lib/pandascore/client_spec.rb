require "rails_helper"

RSpec.describe Pandascore::Client do
  let(:token) { "test_token" }

  describe "#get" do
    context "with injected http stub" do
      let(:fake_http) do
        Class.new do
          def get(path, params)
            [{ "id" => 1, "name" => "Natus Vincere" }]
          end
        end.new
      end

      it "delegates to the injected http object" do
        client = described_class.new(token: token, http: fake_http)
        result = client.get("/csgo/teams", sort: "ranking")
        expect(result).to eq([{ "id" => 1, "name" => "Natus Vincere" }])
      end
    end

    context "with real Net::HTTP" do
      let(:response_body) { [{ "id" => 1 }].to_json }

      let(:fake_response) do
        instance_double(Net::HTTPOK, is_a?: true, body: response_body).tap do |r|
          allow(r).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        end
      end

      before do
        allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_response)
        allow_any_instance_of(described_class).to receive(:sleep)
      end

      it "sends Authorization header and parses JSON" do
        client = described_class.new(token: token)
        expect_any_instance_of(Net::HTTP).to receive(:request) do |_http, req|
          expect(req["Authorization"]).to eq("Bearer #{token}")
          fake_response
        end
        result = client.get("/csgo/teams")
        expect(result).to eq([{ "id" => 1 }])
      end

      context "when response is non-2xx" do
        let(:fake_error_response) do
          instance_double(Net::HTTPForbidden).tap do |r|
            allow(r).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
            allow(r).to receive(:code).and_return("403")
          end
        end

        before do
          allow_any_instance_of(Net::HTTP).to receive(:request).and_return(fake_error_response)
        end

        it "raises Pandascore::Error" do
          client = described_class.new(token: token)
          expect { client.get("/csgo/teams") }.to raise_error(Pandascore::Error)
        end
      end
    end
  end
end
