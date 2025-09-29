# frozen_string_literal: true

# Cucumber hooks for setup and teardown

# Set up before each scenario
Before do
  # Clear any instance variables from previous scenarios
  @api_error_scenario = false
end

# Clean up after each scenario
After do
  # Ensure VCR is turned back on if it was disabled
  VCR.turn_on! if defined?(VCR) && !VCR.turned_on?

  # Clear instance variables
  @api_error_scenario = false
end

# Clean up after all scenarios complete
at_exit do
  if defined?(Capybara)
    # Reset sessions and clean up any servers
    Capybara.reset_sessions!
    # Quit current driver if it supports it (for browser drivers)
    if Capybara.current_session.driver.respond_to?(:quit)
      begin
        Capybara.current_session.driver.quit
      rescue StandardError
        # Ignore errors during cleanup
      end
    end
  end
end

# Clean up after error scenarios specifically
After("@api_error") do
  # Reset WebMock after error scenarios
  WebMock.reset! if defined?(WebMock)
end
