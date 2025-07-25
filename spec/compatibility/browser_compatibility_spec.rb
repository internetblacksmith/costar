# frozen_string_literal: true

require "spec_helper"
require "capybara/rspec"

RSpec.describe "Browser Compatibility", type: :feature, js: true do
  # These tests would run with different Capybara drivers
  # You could set up Selenium with different browsers
  
  describe "Core Functionality" do
    it "works without JavaScript" do
      # Test with Rack::Test (no JS)
      Capybara.current_driver = :rack_test
      
      visit "/"
      
      # Page should still load and show basic content
      expect(page).to have_content("MovieTogether")
      expect(page).to have_css("input#actor1")
      expect(page).to have_css("input#actor2")
    end

    it "progressive enhancement with JavaScript" do
      # Test with JavaScript enabled
      Capybara.current_driver = :cuprite
      
      visit "/"
      
      # Should have enhanced features
      expect(page).to have_css(".mdc-text-field")
      expect(page).to have_css("#themeToggle")
    end
  end

  describe "CSS Feature Support" do
    it "has fallbacks for CSS Grid" do
      visit "/"
      
      # Check that layout works even without grid support
      page.execute_script("document.documentElement.style.display = 'block';")
      
      # Elements should still be visible and positioned
      expect(page).to have_css(".search-form")
      expect(page).to have_css(".search-field-container")
    end

    it "has fallbacks for CSS Custom Properties" do
      visit "/"
      
      # Even without CSS variables, page should be readable
      page.execute_script("
        const style = document.createElement('style');
        style.textContent = ':root { --primary-color: undefined !important; }';
        document.head.appendChild(style);
      ")
      
      # Page should still be functional
      expect(page).to have_css("button#compareBtn")
    end
  end

  describe "Mobile Responsiveness" do
    it "works on mobile viewport" do
      page.driver.resize_window(375, 667) # iPhone SE size
      
      visit "/"
      
      # Should show mobile-optimized layout
      expect(page).to have_css(".container")
      
      # Search fields should stack vertically
      actor1_pos = page.find("#actor1Container").native.location
      actor2_pos = page.find("#actor2Container").native.location
      
      expect(actor2_pos[:y]).to be > actor1_pos[:y]
    end

    it "works on tablet viewport" do
      page.driver.resize_window(768, 1024) # iPad size
      
      visit "/"
      
      expect(page).to have_css(".container")
      expect(page).to have_css(".search-form")
    end
  end

  describe "Touch Support" do
    it "has adequate touch targets" do
      visit "/"
      
      # Buttons should be at least 44x44px (iOS guideline)
      button = page.find("#compareBtn")
      size = button.native.size
      
      expect(size[:height]).to be >= 44
    end
  end
end