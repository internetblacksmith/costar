#!/usr/bin/env ruby
# frozen_string_literal: true

require "sinatra"
require "fileutils"
require "dotenv"
require "open3"
require "shellwords"

class DevServer
  def initialize
    @project_root = File.expand_path("..", __dir__)
    @required_commands = %w[bundle ruby]
    @optional_commands = %w[doppler]
  end

  def start
    puts "🎬 CoStar Development Server"
    puts "================================\n"

    check_project_directory
    check_dependencies
    check_environment_setup
    validate_environment
    install_dependencies
    start_server
  end

  private

  def check_project_directory
    unless File.exist?(File.join(@project_root, "app.rb"))
      puts "❌ Error: Not in CoStar project directory"
      puts "   Expected to find app.rb in #{@project_root}"
      exit(1)
    end
    puts "✅ Project directory confirmed"
  end

  def check_dependencies
    missing_commands = []

    @required_commands.each do |cmd|
      missing_commands << cmd unless command_available?(cmd)
    end

    unless missing_commands.empty?
      puts "❌ Missing required commands: #{missing_commands.join(", ")}"
      puts "   Please install Ruby and Bundler before continuing"
      exit(1)
    end

    puts "✅ Required dependencies available"

    # Check optional commands
    @optional_commands.each do |cmd|
      if command_available?(cmd)
        puts "✅ #{cmd} available"
      else
        puts "⚠️  #{cmd} not found (optional but recommended)"
      end
    end
  end

  def check_environment_setup
    puts "\n🔍 Checking environment configuration..."

    if doppler_configured?
      puts "✅ Doppler configured for this project"
      @use_doppler = true
    elsif File.exist?(File.join(@project_root, ".env"))
      puts "✅ .env file found"
      puts "💡 Consider switching to Doppler for better secret management"
      @use_doppler = false
    else
      puts "❌ No environment configuration found"
      puts "\nOptions:"
      puts "1. Set up Doppler (recommended):"
      puts "   brew install doppler  # or visit https://docs.doppler.com/docs/install-cli"
      puts "   doppler login"
      puts "   doppler setup"
      puts ""
      puts "2. Create .env file with required variables:"
      puts "   cp .env.example .env  # and edit with your values"
      exit(1)
    end
  end

  def validate_environment
    puts "\n🔍 Validating environment variables..."

    # Run validation using our Configuration class
    validation_cmd = if @use_doppler
                       "doppler run -- ruby -e \"require './lib/config/configuration'; Configuration.instance\""
                     else
                       "ruby -e \"require './lib/config/configuration'; Configuration.instance\""
                     end

    output, status = Open3.capture2e(validation_cmd, chdir: @project_root)

    unless status.success?
      puts "❌ Environment validation failed:"
      puts output
      puts "\nPlease fix the configuration issues before starting the server."
      exit(1)
    end

    puts output if output.strip.length.positive?
  end

  def install_dependencies
    puts "\n📦 Installing dependencies..."

    gemfile_lock = File.join(@project_root, "Gemfile.lock")
    if File.exist?(gemfile_lock)
      # Check if dependencies are up to date
      _, status = Open3.capture2e("bundle check", chdir: @project_root)
      if status.success?
        puts "✅ Dependencies are up to date"
        return
      end
    end

    puts "   Running bundle install..."
    output, status = Open3.capture2e("bundle install", chdir: @project_root)

    unless status.success?
      puts "❌ Failed to install dependencies:"
      puts output
      exit(1)
    end

    puts "✅ Dependencies installed successfully"
  end

  def start_server
    puts "\n🚀 Starting development server..."
    puts "   Server will be available at: http://localhost:4567"
    puts "   Press Ctrl+C to stop\n"

    server_cmd = if @use_doppler
                   "doppler run -- ./scripts/server"
                 else
                   "./scripts/server"
                 end

    puts "Command: #{server_cmd}"
    puts "=" * 50

    # Start the server
    Dir.chdir(@project_root) do
      exec(server_cmd)
    end
  end

  def command_available?(cmd)
    system("which #{Shellwords.escape(cmd)} > /dev/null 2>&1")
  end

  def doppler_configured?
    return false unless command_available?("doppler")

    # Check if doppler is configured for this project
    _, status = Open3.capture2e("doppler secrets --silent", chdir: @project_root)
    status.success?
  end
end

# Check if we're being run directly
DevServer.new.start if __FILE__ == $PROGRAM_NAME
