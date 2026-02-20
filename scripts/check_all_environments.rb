#!/usr/bin/env ruby
# frozen_string_literal: true

# Comprehensive Environment Check Wrapper
# Checks both Doppler configurations and local environment setup

puts "🌍 CoStar Complete Environment Validation"
puts "=" * 70
puts

# Check if we're running with Doppler
doppler_env = ENV.fetch("DOPPLER_ENVIRONMENT", nil)
if doppler_env
  puts "🔗 Running with Doppler environment: #{doppler_env.upcase}"
  puts "Checking current environment variables..."
  puts

  # Run the original environment checker for current context
  require_relative "check_env_variables"
  checker = EnvironmentChecker.new
  checker.check_environment

  puts "\n#{"=" * 70}"
  puts
end

puts "🔍 Checking all Doppler configurations..."
puts

# Run the comprehensive Doppler checker
require_relative "check_doppler_environments"
doppler_checker = DopplerEnvironmentChecker.new
doppler_checker.check_all_environments

puts "\n#{"=" * 70}"
puts "✅ Complete environment validation finished!"
puts

if doppler_env
  puts "💡 TIP: You're currently using Doppler environment: #{doppler_env.upcase}"
  puts "   To switch environments, use: doppler run --config <env> -- <command>"
else
  puts "💡 TIP: To run with a specific Doppler environment:"
  puts "   doppler run --config dev -- ruby your_script.rb"
  puts "   doppler run --config stg -- ruby your_script.rb"
  puts "   doppler run --config prd -- ruby your_script.rb"
end
