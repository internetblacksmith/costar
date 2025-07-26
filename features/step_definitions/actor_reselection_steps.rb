# frozen_string_literal: true

# Step definitions for actor reselection feature

Given("I am on the MovieTogether homepage") do
  visit "/"
  expect(page.status_code).to eq(200)
end

When("I fill in {string} with {string}") do |field, value|
  fill_in field, with: value
end

When("I click the clear button for {string}") do |field|
  # When an actor is selected, it shows as a chip with a cancel icon
  # Find the container for the field and click the trailing icon
  container = find("##{field}Container")
  clear_button = container.find(".mdc-chip__trailing-icon", visible: true)
  clear_button.click

  # Wait for the input field to be recreated and HTMX to process it
  sleep 1

  # Wait for the input field to be visible and ready
  expect(page).to have_css("##{field}", wait: 2)
end

Then("the {string} field should be empty") do |field|
  field_element = find("##{field}")
  expect(field_element.value).to eq("")
end

Then("the {string} field should contain {string}") do |field, value|
  # When an actor is selected, the field becomes a chip
  # Check if we have a chip or an input field
  container = find("##{field}Container")

  if container.has_css?(".mdc-chip")
    # Actor is selected as a chip
    chip_text = container.find(".mdc-chip__text").text
    expect(chip_text).to eq(value)
  else
    # Regular input field
    field_element = find("##{field}")
    expect(field_element.value).to eq(value)
  end
end

Then("the {string} hidden field should be empty") do |field|
  hidden_field = find("##{field}", visible: false)
  expect(hidden_field.value).to eq("")
end

Then("the {string} hidden field should have a value") do |field|
  hidden_field = find("##{field}", visible: false)
  expect(hidden_field.value).not_to be_empty
  expect(hidden_field.value).to match(/^\d+$/) # Should be a numeric ID
end

When("I wait for suggestions to appear") do
  # Determine which field was last filled (check which one has focus or content)
  field_id = if page.has_css?("#actor1:focus") || (!find("#actor1").value.empty? && find("#actor2").value.empty?)
               "actor1"
             else
               "actor2"
             end

  suggestions_id = field_id == "actor1" ? "suggestions1" : "suggestions2"

  # Manually trigger HTMX if needed
  page.execute_script("
    const input = document.getElementById('#{field_id}');
    if (input && typeof htmx !== 'undefined') {
      htmx.trigger(input, 'keyup');
    }
  ")

  # Wait for suggestions to appear (with longer timeout for HTMX delay)
  expect(page).to have_css("##{suggestions_id} .suggestion-item", wait: 5)
end

When("I select {string} from the suggestions for {string}") do |actor_name, _field|
  # Find and click the suggestion item containing the actor name
  suggestion = find(".suggestion-item", text: actor_name, match: :first)
  suggestion.click

  # Wait for the selection to be processed
  sleep 0.5
end
