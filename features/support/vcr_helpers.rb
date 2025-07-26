# frozen_string_literal: true

# VCR helper for managing cassettes in Cucumber tests

Around("@vcr") do |scenario, block|
  # Generate cassette name from scenario
  cassette_name = generate_cassette_name(scenario)

  # Use VCR with the generated cassette name
  VCR.use_cassette(cassette_name, record: vcr_record_mode) do
    block.call
  end
rescue VCR::Errors::UnhandledHTTPRequestError => e
  # Provide helpful error message for missing cassettes
  if ENV["CI"] == "true"
    raise "Missing VCR cassette in CI: #{cassette_name}. " \
          "Please record this cassette in development mode and commit it.\n" \
          "Original error: #{e.message}"
  else
    raise "Unhandled HTTP request. Set VCR_RECORD_MODE=new_episodes to record it.\n" \
          "Original error: #{e.message}"
  end
end

def generate_cassette_name(scenario)
  # Create a cassette name from feature and scenario names
  # In Cucumber 10, the API has changed
  feature_name = scenario.location.file.gsub(%r{^features/}, "").gsub(/\.feature$/, "")
  scenario_name = scenario.name.downcase.gsub(/\s+/, "_")

  # Remove special characters
  feature_name = feature_name.gsub(%r{[^a-z0-9_/]}, "")
  scenario_name = scenario_name.gsub(/[^a-z0-9_]/, "")

  "#{feature_name}/#{scenario_name}"
end

def vcr_record_mode
  mode = ENV["VCR_RECORD_MODE"]&.to_sym

  # Default modes based on environment
  if ENV["CI"] == "true"
    :none # Never record in CI
  elsif mode
    mode # Use explicitly set mode
  else
    :once # Default for development
  end
end
