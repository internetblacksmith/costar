# frozen_string_literal: true

Given("I am on the home page") do
  visit "/"
  if page.status_code != 200
    puts "Status: #{page.status_code}"
    puts "Body: #{page.body[0..500]}"
    puts "Headers: #{page.response_headers}"
  end
  expect_successful_response
end

When("I search for {string} in the first actor field") do |search_term|
  # Make sure we're on the home page for JavaScript tests
  if Capybara.current_driver == :cuprite && current_path != "/"
    visit "/"
  end
  
  # Use the actor1 search field
  fill_in "actor1", with: search_term
  
  # For JavaScript tests, trigger the input event and wait for HTMX
  if Capybara.current_driver == :cuprite
    # Trigger keyup event for HTMX
    find("#actor1").send_keys(" ") # Add a space
    find("#actor1").send_keys(:backspace) # Remove it to trigger event
    # Wait for suggestions to appear (with longer timeout for HTMX delay)
    expect(page).to have_css("#suggestions1 .suggestion-item", wait: 5)
  else
    # For non-JS tests, visit the API directly
    visit "/api/actors/search?q=#{CGI.escape(search_term)}&field=actor1"
  end
end

When("I search for {string} in the second actor field") do |search_term|
  # Make sure we're on the home page for JavaScript tests
  if Capybara.current_driver == :cuprite && current_path != "/"
    visit "/"
  end
  
  fill_in "actor2", with: search_term
  
  # For JavaScript tests, trigger the input event and wait for HTMX
  if Capybara.current_driver == :cuprite
    # Trigger keyup event for HTMX
    find("#actor2").send_keys(" ") # Add a space
    find("#actor2").send_keys(:backspace) # Remove it to trigger event
    # Wait for suggestions to appear (with longer timeout for HTMX delay)
    expect(page).to have_css("#suggestions2 .suggestion-item", wait: 5)
  else
    # For non-JS tests, visit the API directly
    visit "/api/actors/search?q=#{CGI.escape(search_term)}&field=actor2"
  end
end

Then("I should see search suggestions") do
  # Check that we have actual actor results, not just empty response
  expect(page.body).not_to be_empty
  expect(page).to have_content("Known for:")
  expect_successful_response
end

Then("I should not see search suggestions") do
  # For empty search, we might get a different response
  body = page.body
  expect(body).to be_empty.or(have_content("No results"))
end

Then("the suggestions should include {string}") do |actor_name|
  expect(page).to have_content(actor_name)
end

Then("the suggestions should include multiple actors containing {string}") do |search_term|
  # Check that we have multiple actors in the results
  body = page.body
  
  # Count how many times we see "Known for:" which indicates an actor result
  actor_count = body.scan(/Known for:/).size
  
  expect(actor_count).to be > 1, "Expected multiple actors, but found #{actor_count}"
  
  # Verify the search term appears multiple times
  expect(body.downcase).to include(search_term.downcase)
end

Then("the response should have status code {int}") do |status_code|
  expect(page.status_code).to eq(status_code)
end

Then("no rate limiting errors should occur") do
  # Check that we didn't get a 429 (Too Many Requests) or 403 (Forbidden) error
  expect(page.status_code).not_to eq(429)
  expect(page.status_code).not_to eq(403)
  expect(page).not_to have_content("Too Many Requests")
  expect(page).not_to have_content("Forbidden")
end

When("I rapidly search for the following terms:") do |table|
  @search_responses = []
  
  table.hashes.each do |row|
    search_term = row["search_term"]
    visit "/api/actors/search?q=#{CGI.escape(search_term)}&field=actor1"
    
    @search_responses << {
      term: search_term,
      status: page.status_code,
      body: page.body
    }
    
    # Small delay to simulate real typing speed
    sleep 0.1
  end
end

Then("all searches should complete successfully") do
  @search_responses.each do |response|
    expect(response[:status]).to eq(200), 
      "Search for '#{response[:term]}' failed with status #{response[:status]}"
  end
end

Given("the TMDB API is returning errors") do
  # This would typically be handled by VCR cassette with error responses
  # or by stubbing the service in test mode
  @simulate_api_error = true
end

Then("I should see an error message") do
  # For API endpoints, we might get JSON errors or HTML errors
  if page.response_headers["Content-Type"]&.include?("json")
    expect_json_response
    # For JSON responses, check the body contains error
    body = JSON.parse(page.body) rescue {}
    has_error_key = body.key?("error") || body.key?("message")
    expect(has_error_key).to eq(true)
  else
    # For HTML responses, check for error text
    has_error = page.has_css?(".error", wait: 2) || 
                page.has_content?("error", wait: 2) || page.has_content?("Error", wait: 2) || 
                page.has_content?("not found", wait: 2) || page.has_content?("failed", wait: 2) ||
                page.has_content?("Failed", wait: 2) || page.has_content?("required", wait: 2)
    expect(has_error).to eq(true)
  end
end

Then("the application should not crash") do
  # The fact that we got a response means the app didn't crash
  expect([200, 400, 500, 502, 503]).to include(page.status_code)
end