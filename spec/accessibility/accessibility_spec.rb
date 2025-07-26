# frozen_string_literal: true

require "spec_helper"
require "capybara/rspec"
require "axe/rspec"

RSpec.describe "Accessibility", type: :feature, js: true do
  before do
    # Use Cuprite (headless Chrome) for JavaScript support
    Capybara.current_driver = :cuprite
  end

  after do
    Capybara.use_default_driver
  end

  describe "Home page" do
    it "meets WCAG 2.0 AA accessibility standards" do
      visit "/"
      
      # Wait for page to fully load
      expect(page).to have_css(".search-form")
      
      # Run accessibility scan
      expect(page).to be_accessible.according_to :wcag2a, :wcag2aa
    end

    it "has no accessibility violations in light mode" do
      visit "/"
      
      # Ensure we're in light mode
      page.execute_script("localStorage.setItem('theme', 'light'); document.documentElement.setAttribute('data-theme', 'light');")
      
      expect(page).to be_accessible.according_to :wcag2a, :wcag2aa
    end

    it "has no accessibility violations in dark mode" do
      visit "/"
      
      # Switch to dark mode
      page.execute_script("localStorage.setItem('theme', 'dark'); document.documentElement.setAttribute('data-theme', 'dark');")
      
      expect(page).to be_accessible.according_to :wcag2a, :wcag2aa
    end
  end

  describe "Search functionality" do
    it "search suggestions are accessible", :pending => "Requires VCR cassette for TMDB API" do
      visit "/"
      
      # Trigger search
      fill_in "actor1", with: "Tom"
      
      # Wait for suggestions
      expect(page).to have_css(".suggestion-item", wait: 5)
      
      # Check accessibility of the suggestions
      expect(page).to be_accessible.according_to :wcag2a, :wcag2aa
    end

    it "selected actor chips are accessible", :pending => "Requires VCR cassette for TMDB API" do
      visit "/"
      
      # Select an actor (using pre-recorded VCR cassette)
      fill_in "actor1", with: "Tom Hanks"
      page.execute_script("htmx.trigger(document.getElementById('actor1'), 'keyup');")
      
      expect(page).to have_css(".suggestion-item", wait: 5)
      first(".suggestion-item").click
      
      # Wait for chip to appear
      expect(page).to have_css(".selected-actor-chip")
      
      # Check accessibility
      expect(page).to be_accessible.according_to :wcag2a, :wcag2aa
    end
  end

  describe "Timeline comparison" do
    it "timeline view is accessible", :pending => "Requires VCR cassette for TMDB API" do
      # Use direct URL to avoid needing to interact with search
      visit "/api/actors/compare?actor1_id=31&actor2_id=5344"
      
      # Wait for timeline to load
      expect(page).to have_css(".timeline", wait: 5)
      
      # Check accessibility
      expect(page).to be_accessible.according_to :wcag2a, :wcag2aa
    end
  end

  describe "Color contrast" do
    it "meets minimum contrast ratios in light mode" do
      visit "/"
      
      # Light mode
      page.execute_script("localStorage.setItem('theme', 'light'); document.documentElement.setAttribute('data-theme', 'light');")
      
      # Specific contrast checks
      expect(page).to be_accessible
        .according_to(:wcag2aa)
        .checking_only(:"color-contrast")
    end

    it "meets minimum contrast ratios in dark mode" do
      visit "/"
      
      # Dark mode
      page.execute_script("localStorage.setItem('theme', 'dark'); document.documentElement.setAttribute('data-theme', 'dark');")
      
      # Specific contrast checks
      expect(page).to be_accessible
        .according_to(:wcag2aa)
        .checking_only(:"color-contrast")
    end
  end

  describe "Keyboard navigation" do
    it "all interactive elements are keyboard accessible" do
      visit "/"
      
      # Check for keyboard accessibility using valid axe rules
      expect(page).to be_accessible
        .according_to(:wcag2a)
        .checking_only(:tabindex)
    end
  end

  describe "Form labels and ARIA" do
    it "all form inputs have proper labels" do
      visit "/"
      
      # Check for proper labeling
      expect(page).to be_accessible
        .according_to(:wcag2a)
        .checking_only([:label, :"aria-required-attr", :"aria-valid-attr"])
    end
  end
end