#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple accessibility check script
require "bundler/setup"
require "net/http"
require "json"
require "uri"

# Run a lighthouse accessibility audit using Google PageSpeed API
def check_accessibility(url)
  api_url = "https://www.googleapis.com/pagespeedonline/v5/runPagespeed"
  params = {
    url: url,
    category: "accessibility"
  }

  uri = URI(api_url)
  uri.query = URI.encode_www_form(params)

  response = Net::HTTP.get_response(uri)

  if response.code == "200"
    data = JSON.parse(response.body)

    # Extract accessibility score
    score = data.dig("lighthouseResult", "categories", "accessibility", "score")

    if score
      puts "Accessibility Score: #{(score * 100).round}%"

      # Extract audit results
      audits = data.dig("lighthouseResult", "audits")

      if audits
        puts "\nKey Accessibility Issues:"
        audits.each_value do |audit_data|
          next unless audit_data["score"] && audit_data["score"] < 1 && audit_data["details"]

          puts "\n- #{audit_data["title"]}"
          puts "  #{audit_data["description"]}" if audit_data["description"]
        end
      end
    else
      puts "Could not extract accessibility score"
    end
  else
    puts "Error: #{response.code} - #{response.message}"
  end
rescue StandardError => e
  puts "Error running accessibility check: #{e.message}"
end

# Check if server is running
def server_running?(url)
  uri = URI(url)
  response = Net::HTTP.get_response(uri)
  response.code == "200"
rescue StandardError
  false
end

# Main execution
if ARGV.empty?
  puts "Usage: ruby accessibility_check.rb <URL>"
  puts "Example: ruby accessibility_check.rb http://localhost:9393"
  exit 1
end

url = ARGV[0]

if server_running?(url)
  puts "Checking accessibility for: #{url}"
  check_accessibility(url)
else
  puts "Error: Server is not running at #{url}"
  puts "Please start the development server first with: make dev"
  exit 1
end
