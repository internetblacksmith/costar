# frozen_string_literal: true

require_relative "health_handler"

# Health check controller for monitoring application status
module HealthController
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def health_check_endpoint
      get "/health/complete" do
        content_type :json
        HealthHandler.new(self).handle
      end
    end
  end
end
