# frozen_string_literal: true

# Common step definitions that can be used across features

Then("I should see {string}") do |text|
  expect(page).to have_content(text)
end

Then("I should not see {string}") do |text|
  expect(page).not_to have_content(text)
end

When("I click {string}") do |text|
  # Debug: Check hidden field values before clicking
  if text.include?("Explore")
    puts "Actor1 ID: #{find('#actor1_id_backup', visible: false).value}"
    puts "Actor2 ID: #{find('#actor2_id_backup', visible: false).value}"
    puts "Actor1 Name: #{find('#actor1_name_backup', visible: false).value}"
    puts "Actor2 Name: #{find('#actor2_name_backup', visible: false).value}"
  end
  
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
  puts page.body
end

Then("show me the response headers") do
  puts page.response_headers.inspect
end

Then("show me the current path") do
  puts current_path
end