require "net/http"
require "json"

module Pandascore
  class Client
    BASE_URL = "https://api.pandascore.co"

    def initialize(token:, http: nil)
      @token = token
      @http = http
    end

    def get(path, params = {})
      if @http
        @http.get(path, params)
      else
        uri = URI("#{BASE_URL}#{path}")
        uri.query = URI.encode_www_form(params).gsub("%5B", "[").gsub("%5D", "]") unless params.empty?

        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{@token}"

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
          http.request(request)
        end
        binding.irb

        sleep 1

        unless response.is_a?(Net::HTTPSuccess)
          Rails.logger.error "Pandascore: #{response.code} #{uri}"
          raise Pandascore::Error, "HTTP #{response.code}: #{uri}"
        end

        JSON.parse(response.body)
      end
    end
  end
end
