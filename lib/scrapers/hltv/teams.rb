module Scrapers
  module Hltv
    class Teams
      URL = "https://www.hltv.org/ranking/teams"
      WAIT_TIMEOUT = 15

      def self.call(limit: nil)
        new(limit: limit).call
      end

      def initialize(limit: nil)
        @limit = limit
      end

      def call
        html = fetch_html
        teams = parse(html)
        @limit ? teams.first(@limit) : teams
      end

      private

      def fetch_html
        options = Selenium::WebDriver::Chrome::Options.new
        options.add_argument("--headless=new")
        options.add_argument("--no-sandbox")
        options.add_argument("--disable-dev-shm-usage")
        options.add_argument("--disable-blink-features=AutomationControlled")
        options.add_argument("--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36")

        driver = Selenium::WebDriver.for(:chrome, options: options)
        begin
          driver.navigate.to(URL)
          Selenium::WebDriver::Wait.new(timeout: WAIT_TIMEOUT).until do
            driver.find_elements(css: ".ranked-team").any?
          end
          driver.page_source
        rescue Selenium::WebDriver::Error::TimeoutError
          raise Error, "Timed out waiting for ranked teams on #{URL}"
        ensure
          driver.quit
        end
      end

      def parse(html)
        doc = Nokogiri::HTML(html)
        doc.css(".ranked-team").map do |el|
          rank = el.css(".position").text.gsub(/\D/, "").to_i
          name = el.css(".name").text.strip
          link = el.at_css("a[href*='/team/']")
          next unless link

          hltv_id = link["href"].match(%r{/team/(\d+)/})&.captures&.first&.to_i
          next unless hltv_id

          region = el.at_css(".flag")&.attr("title")
          { hltv_id: hltv_id, name: name, hltv_rank: rank, region: region }
        end.compact
      end
    end
  end
end
