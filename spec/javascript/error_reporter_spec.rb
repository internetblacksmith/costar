# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Frontend Error Handling", type: :request do
  describe "error-reporter.js" do
    it "is served successfully" do
      get "/js/modules/error-reporter.js"
      expect(last_response.status).to eq(200)
      expect(last_response.content_type).to include("text/javascript")
    end

    it "contains error handling functionality" do
      get "/js/modules/error-reporter.js"

      expect(last_response.body).to include("class ErrorReporter")
      expect(last_response.body).to include("handleError")
      expect(last_response.body).to include("handleHTMXError")
      expect(last_response.body).to include("window.addEventListener('error'")
      expect(last_response.body).to include("window.addEventListener('unhandledrejection'")
    end

    it "includes Sentry integration" do
      get "/js/modules/error-reporter.js"

      expect(last_response.body).to include("Sentry.captureException")
      expect(last_response.body).to include("typeof Sentry !== 'undefined'")
    end

    it "includes user notification functionality" do
      get "/js/modules/error-reporter.js"

      expect(last_response.body).to include("showUserNotification")
      expect(last_response.body).to include("window.snackbarModule")
    end

    it "includes HTMX error handling" do
      get "/js/modules/error-reporter.js"

      expect(last_response.body).to include("htmx:responseError")
      expect(last_response.body).to include("htmx:sendError")
      expect(last_response.body).to include("htmx:sseError")
      expect(last_response.body).to include("htmx:oobError")
    end

    it "includes error deduplication logic" do
      get "/js/modules/error-reporter.js"

      expect(last_response.body).to include("createErrorSignature")
      expect(last_response.body).to include("reportedErrors")
      expect(last_response.body).to include("maxErrorsPerSession")
    end
  end

  describe "layout.erb integration" do
    it "includes error-reporter.js before other modules" do
      get "/"

      # Check that error-reporter.js is loaded before other modules
      error_reporter_pos = last_response.body.index("/js/modules/error-reporter.js")
      snackbar_pos = last_response.body.index("/js/modules/snackbar.js")
      actor_search_pos = last_response.body.index("/js/modules/actor-search.js")
      app_pos = last_response.body.index("/js/app.js")

      expect(error_reporter_pos).to be < snackbar_pos
      expect(error_reporter_pos).to be < actor_search_pos
      expect(error_reporter_pos).to be < app_pos
    end

    context "with SENTRY_DSN configured" do
      let(:sentry_dsn) { "https://test@sentry.io/123456" }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("SENTRY_DSN").and_return(sentry_dsn)
      end

      it "includes Sentry SDK" do
        get "/"

        expect(last_response.body).to include("browser.sentry-cdn.com")
        expect(last_response.body).to include("Sentry.init")
        expect(last_response.body).to include(sentry_dsn)
      end
    end

    context "without SENTRY_DSN configured" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with("SENTRY_DSN").and_return(nil)
      end

      it "does not include Sentry SDK" do
        get "/"

        expect(last_response.body).not_to include("browser.sentry-cdn.com")
        expect(last_response.body).not_to include("Sentry.init")
      end
    end
  end

  describe "actor-search.js error handling" do
    it "includes error handling in key methods" do
      get "/js/modules/actor-search.js"

      # Check that try-catch blocks are added
      expect(last_response.body).to include("try {")
      expect(last_response.body).to include("ErrorReporter.report")
      expect(last_response.body).to include("phase: 'actor_search_init'")
      expect(last_response.body).to include("phase: 'actor_selection'")
      expect(last_response.body).to include("phase: 'remove_actor'")
    end
  end

  describe "app.js error handling" do
    it "reports initialization errors" do
      get "/js/app.js"

      expect(last_response.body).to include("ErrorReporter.report")
      expect(last_response.body).to include("phase: 'initialization'")
    end
  end
end
