# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Modular JavaScript", type: :request do
  describe "new JavaScript modules" do
    it "serves dom-manager.js successfully" do
      get "/js/modules/dom-manager.js"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/javascript")
    end

    it "serves event-manager.js successfully" do
      get "/js/modules/event-manager.js"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/javascript")
    end

    it "serves analytics-tracker.js successfully" do
      get "/js/modules/analytics-tracker.js"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/javascript")
    end

    it "serves field-manager.js successfully" do
      get "/js/modules/field-manager.js"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/javascript")
    end

    it "serves mobile-keyboard.js successfully" do
      get "/js/modules/mobile-keyboard.js"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/javascript")
    end
  end

  describe "module content" do
    it "dom-manager.js contains DOM manipulation utilities" do
      get "/js/modules/dom-manager.js"

      expect(last_response.body).to include("class DOMManager")
      expect(last_response.body).to include("getElement")
      expect(last_response.body).to include("setValue")
      expect(last_response.body).to include("createChipHTML")
      expect(last_response.body).to include("createTextFieldHTML")
      expect(last_response.body).to include("createLoadingHTML")
      expect(last_response.body).to include("initializeMDC")
    end

    it "event-manager.js contains event handling utilities" do
      get "/js/modules/event-manager.js"

      expect(last_response.body).to include("class EventManager")
      expect(last_response.body).to include("addEventListener")
      expect(last_response.body).to include("delegate")
      expect(last_response.body).to include("onHTMXBeforeRequest")
      expect(last_response.body).to include("onHTMXAfterRequest")
      expect(last_response.body).to include("onHTMXResponseError")
      expect(last_response.body).to include("debounce")
    end

    it "analytics-tracker.js contains analytics utilities" do
      get "/js/modules/analytics-tracker.js"

      expect(last_response.body).to include("class AnalyticsTracker")
      expect(last_response.body).to include("trackActorSelection")
      expect(last_response.body).to include("trackComparisonStarted")
      expect(last_response.body).to include("trackComparisonCompleted")
      expect(last_response.body).to include("posthog")
    end

    it "field-manager.js contains field management utilities" do
      get "/js/modules/field-manager.js"

      expect(last_response.body).to include("class FieldManager")
      expect(last_response.body).to include("getFieldConfig")
      expect(last_response.body).to include("setActorValues")
      expect(last_response.body).to include("clearActorValues")
      expect(last_response.body).to include("isShareLink")
    end

    it "mobile-keyboard.js contains mobile keyboard handling utilities" do
      get "/js/modules/mobile-keyboard.js"

      expect(last_response.body).to include("class MobileKeyboard")
      expect(last_response.body).to include("isMobile")
      expect(last_response.body).to include("handleInputFocus")
      expect(last_response.body).to include("scrollInputToTop")
      expect(last_response.body).to include("MOBILE_BREAKPOINT")
    end
  end

  describe "refactored actor-search.js" do
    it "uses the new modular components" do
      get "/js/modules/actor-search.js"

      # Check for new module usage
      expect(last_response.body).to include("EventManager")
      expect(last_response.body).to include("DOMManager")
      expect(last_response.body).to include("FieldManager")
      expect(last_response.body).to include("AnalyticsTracker")

      # Check for refactored methods
      expect(last_response.body).to include("this.eventManager = new EventManager()")
      expect(last_response.body).to include("displayActorChip")
      expect(last_response.body).to include("displayInputField")

      # Verify it's much shorter than before (was 274 lines, now ~171)
      line_count = last_response.body.lines.count
      expect(line_count).to be < 200
    end
  end

  describe "module loading order" do
    it "loads modules in correct dependency order" do
      get "/"

      # Get positions of script tags
      dom_manager_pos = last_response.body.index("/js/modules/dom-manager.js")
      event_manager_pos = last_response.body.index("/js/modules/event-manager.js")
      analytics_pos = last_response.body.index("/js/modules/analytics-tracker.js")
      field_manager_pos = last_response.body.index("/js/modules/field-manager.js")
      mobile_keyboard_pos = last_response.body.index("/js/modules/mobile-keyboard.js")
      actor_search_pos = last_response.body.index("/js/modules/actor-search.js")

      # Verify dependencies are loaded before actor-search.js
      expect(dom_manager_pos).to be < actor_search_pos
      expect(event_manager_pos).to be < actor_search_pos
      expect(analytics_pos).to be < actor_search_pos
      expect(field_manager_pos).to be < actor_search_pos
      # mobile-keyboard depends on EventManager
      expect(event_manager_pos).to be < mobile_keyboard_pos
    end
  end

  describe "backward compatibility" do
    it "maintains original public API" do
      get "/js/modules/actor-search.js"

      # Check that public methods still exist
      expect(last_response.body).to include("selectActor")
      expect(last_response.body).to include("removeActor")
      expect(last_response.body).to include("trackComparison")
      expect(last_response.body).to include("clearInputFields")
    end
  end
end
