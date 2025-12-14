# frozen_string_literal: true

# Common step definitions that can be used across features

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end

Then("I should not see {string}") do |text|
  expect(page).not_to have_content(text)
end

When("I click {string}") do |text|
  click_on text
end

When("I wait for {int} second(s)") do |seconds|
  sleep seconds
end

Then("I should be on the {string} page") do |page_name|
  case page_name.downcase
  when "home"
    expect(current_path).to eq("/")
  when "timeline"
    expect(current_path).to match(%r{^/timeline})
  else
    raise "Unknown page: #{page_name}"
  end
end

# Debug helpers
Then("show me the page") do
  # Debug step available if needed
end

Then("show me the response headers") do
  # Debug step available if needed
end

Then("show me the current path") do
  # Debug step available if needed
end
