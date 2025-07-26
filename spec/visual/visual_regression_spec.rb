# frozen_string_literal: true

require "spec_helper"
require "capybara/rspec"

RSpec.describe "Visual Regression", type: :feature, js: true do
  before do
    Capybara.current_driver = :cuprite
    # Increase timeout for external resources
    page.driver.browser.timeout = 10
  end

  # NOTE: These tests would require a visual regression tool like Percy or Applitools
  # This is a basic example using screenshots

  describe "Homepage Appearance" do
    it "matches expected layout in light mode" do
      visit "/"

      # Take screenshot
      page.save_screenshot("tmp/screenshots/homepage_light.png")

      # In a real setup, you'd compare with a baseline image
      # expect(page).to match_screenshot("homepage_light")

      # For now, just check key elements are visible
      expect(page).to have_css("header")
      expect(page).to have_css(".search-form")
      expect(page).to have_css("footer")
    end

    it "matches expected layout in dark mode" do
      visit "/"

      # Switch to dark mode
      find("#themeToggle").click
      sleep 0.5 # Wait for transition

      page.save_screenshot("tmp/screenshots/homepage_dark.png")

      # Verify dark mode is active
      expect(page.html).to include('data-theme="dark"')
    end
  end

  describe "Component States" do
    it "input field focus state" do
      visit "/"

      # Focus input
      find("#actor1").click

      page.save_screenshot("tmp/screenshots/input_focused.png")

      # Should show focus styles
      expect(page).to have_css(".mdc-text-field--focused")
    end

    it "actor chip appearance", pending: "Requires VCR cassette for TMDB API" do
      visit "/"

      # Select an actor
      fill_in "actor1", with: "Tom Hanks"
      page.execute_script("htmx.trigger(document.getElementById('actor1'), 'keyup');")

      expect(page).to have_css(".suggestion-item", wait: 5)
      first(".suggestion-item").click

      page.save_screenshot("tmp/screenshots/actor_chip.png")

      expect(page).to have_css(".selected-actor-chip")
    end
  end

  describe "Responsive Layouts" do
    [
      { name: "mobile", width: 375, height: 667 },
      { name: "tablet", width: 768, height: 1024 },
      { name: "desktop", width: 1920, height: 1080 }
    ].each do |viewport|
      it "renders correctly on #{viewport[:name]}" do
        page.driver.resize_window(viewport[:width], viewport[:height])

        visit "/"

        page.save_screenshot("tmp/screenshots/homepage_#{viewport[:name]}.png")

        # Basic visibility checks
        expect(page).to have_css(".container")
        expect(page).to have_css("#compareBtn")
      end
    end
  end
end
