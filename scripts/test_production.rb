#!/usr/bin/env ruby
# frozen_string_literal: true

require "net/http"
require "json"
require "uri"
require "time"
require "optparse"

# Production test script for CoStar
# Tests all API endpoints and verifies deployment success
class ProductionTester
  DEFAULT_TIMEOUT = 10
  API_TIMEOUT = 5

  def initialize(base_url, options = {})
    @base_url = base_url.sub(%r{/$}, "") # Remove trailing slash
    @expected_sha = options[:sha]
    @wait_for_deploy = options[:wait]
    @timeout = options[:timeout] || DEFAULT_TIMEOUT
    @verbose = options[:verbose]
    @results = []
  end

  def run
    puts "🎬 CoStar Production Test Suite"
    puts "=" * 50
    puts "Target: #{@base_url}"
    puts "Timeout: #{@timeout}s per request"

    wait_for_deployment if @wait_for_deploy && @expected_sha

    current_sha = get_current_sha
    puts "Current SHA: #{current_sha}"
    puts "=" * 50

    # Run all tests
    test_health_endpoints
    test_main_page
    test_api_endpoints

    # Print summary
    print_summary

    # Exit with appropriate code
    @results.all? { |r| r[:success] } ? 0 : 1
  end

  private

  def wait_for_deployment
    puts "\n⏳ Waiting for deployment (SHA: #{@expected_sha})..."
    start_time = Time.now
    max_wait = 300 # 5 minutes

    loop do
      current_sha = get_current_sha
      if current_sha == @expected_sha
        puts "✅ Deployment complete! (took #{(Time.now - start_time).round}s)"
        break
      end

      if Time.now - start_time > max_wait
        puts "❌ Timeout waiting for deployment"
        exit 1
      end

      print "." if @verbose
      sleep 5
    end
    puts
  end

  def get_current_sha
    response = make_request("/health/simple")
    return "unknown" unless response[:success]

    data = JSON.parse(response[:body])
    data["git_sha"] || "unknown"
  rescue StandardError
    "unknown"
  end

  def test_health_endpoints
    puts "\n🏥 Testing Health Endpoints"
    puts "-" * 30

    # Simple health check
    test_endpoint(
      name: "Simple Health Check",
      path: "/health/simple",
      expected_status: 200,
      validate: lambda { |body|
        data = JSON.parse(body)
        data["status"] == "ok" && data["git_sha"]
      }
    )

    # Complete health check
    test_endpoint(
      name: "Complete Health Check",
      path: "/health/complete",
      expected_status: 200,
      validate: lambda { |body|
        data = JSON.parse(body)
        data["status"] == "success" &&
        data["data"]["status"] == "healthy" &&
        data["data"]["checks"]
      }
    )
  end

  def test_main_page
    puts "\n🏠 Testing Main Page"
    puts "-" * 30

    test_endpoint(
      name: "Homepage",
      path: "/",
      expected_status: 200,
      validate: lambda { |body|
        body.include?("CoStar") &&
        body.include?("search-form") &&
        body.include?("actor1")
      }
    )
  end

  def test_api_endpoints
    puts "\n🔌 Testing API Endpoints (HTMX/JSON)"
    puts "-" * 30

    # Test actor search with short query (returns HTML for HTMX)
    test_endpoint(
      name: "Actor Search (short query)",
      path: "/api/actors/search?q=a&field=actor1",
      expected_status: 200,
      timeout: API_TIMEOUT,
      validate: lambda { |body|
        # Actor search returns HTML suggestions for HTMX
        body.include?("suggestion-item") &&
        body.include?("selectActor")
      }
    )

    # Test actor search with real name (returns HTML for HTMX)
    test_endpoint(
      name: "Actor Search (Tom Hanks)",
      path: "/api/actors/search?q=tom%20hanks&field=actor1",
      expected_status: 200,
      timeout: API_TIMEOUT,
      validate: lambda { |body|
        # Should return HTML with Tom Hanks in suggestions
        body.include?("suggestion-item") &&
        body.include?("Tom Hanks")
      }
    )

    # Test actor movies (Tom Hanks)
    test_endpoint(
      name: "Actor Movies (Tom Hanks)",
      path: "/api/actors/31/movies",
      expected_status: 200,
      timeout: API_TIMEOUT,
      validate: lambda { |body|
        data = JSON.parse(body)
        data["status"] == "success" &&
        data["data"]["movies"].is_a?(Array) &&
        data["data"]["movies"].length.positive?
      }
    )

    # Test actor comparison (returns HTML timeline for HTMX)
    test_endpoint(
      name: "Actor Comparison",
      path: "/api/actors/compare?actor1_id=31&actor2_id=500",
      expected_status: 200,
      timeout: API_TIMEOUT,
      validate: lambda { |body|
        # Actor comparison returns HTML timeline
        body.include?("timeline") &&
        (body.include?("timeline-content") || body.include?("year-group"))
      }
    )

    # Test error handling (returns success with empty movies for non-existent actor)
    test_endpoint(
      name: "Invalid Actor ID",
      path: "/api/actors/99999999/movies",
      expected_status: 200,
      timeout: API_TIMEOUT,
      validate: lambda { |body|
        # Returns JSON with empty movies array
        data = JSON.parse(body)
        data["status"] == "success" &&
        data["data"]["movies"].is_a?(Array) &&
        data["data"]["movies"].empty?
      }
    )
  end

  def test_endpoint(name:, path:, expected_status:, timeout: nil, validate: nil)
    print "  #{name.ljust(35)}"

    response = make_request(path, timeout: timeout || @timeout)

    success = response[:success] && response[:status] == expected_status
    success &&= validate.call(response[:body]) if validate && response[:body]

    result = {
      name: name,
      path: path,
      success: success,
      status: response[:status],
      error: response[:error],
      duration: response[:duration]
    }

    @results << result

    if success
      puts "✅ (#{response[:duration]}ms)"
    else
      puts "❌ (#{response[:status] || "timeout"} - #{response[:error] || "validation failed"})"
      puts "     Response: #{response[:body][0..200]}..." if @verbose && response[:body]
    end
  rescue StandardError => e
    puts "❌ (error: #{e.message})"
    @results << { name: name, path: path, success: false, error: e.message }
  end

  def make_request(path, timeout: nil)
    uri = URI.parse("#{@base_url}#{path}")
    start_time = Time.now

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.read_timeout = timeout || @timeout
    http.open_timeout = 5

    request = Net::HTTP::Get.new(uri.request_uri)
    request["Accept"] = "application/json"
    request["X-Requested-With"] = "XMLHttpRequest" if path.include?("/api/")

    response = http.request(request)
    duration = ((Time.now - start_time) * 1000).round

    {
      success: true,
      status: response.code.to_i,
      body: response.body,
      duration: duration
    }
  rescue Net::ReadTimeout, Net::OpenTimeout
    {
      success: false,
      error: "Timeout after #{timeout || @timeout}s",
      duration: ((Time.now - start_time) * 1000).round
    }
  rescue StandardError => e
    {
      success: false,
      error: e.message,
      duration: ((Time.now - start_time) * 1000).round
    }
  end

  def print_summary
    puts "\n📊 Test Summary"
    puts "=" * 50

    total = @results.length
    passed = @results.count { |r| r[:success] }
    failed = total - passed

    puts "Total Tests: #{total}"
    puts "Passed: #{passed} ✅"
    puts "Failed: #{failed} ❌"

    if failed.positive?
      puts "\nFailed Tests:"
      @results.reject { |r| r[:success] }.each do |result|
        puts "  - #{result[:name]}: #{result[:error] || "Status #{result[:status]}"}"
      end
    end

    # Performance summary
    api_results = @results.select { |r| r[:path]&.include?("/api/") }
    return unless api_results.any?

    avg_duration = api_results.map { |r| r[:duration] || 0 }.sum / api_results.length
    puts "\nAPI Performance:"
    puts "  Average response time: #{avg_duration}ms"
  end
end

# Command line interface
if __FILE__ == $PROGRAM_NAME
  options = {}

  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options] URL"

    opts.on("-s", "--sha SHA", "Expected git SHA (for deployment verification)") do |sha|
      options[:sha] = sha
    end

    opts.on("-w", "--wait", "Wait for deployment to complete") do
      options[:wait] = true
    end

    opts.on("-t", "--timeout SECONDS", Integer, "Request timeout in seconds (default: 10)") do |t|
      options[:timeout] = t
    end

    opts.on("-v", "--verbose", "Verbose output") do
      options[:verbose] = true
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit
    end
  end.parse!

  url = ARGV[0] || ENV["PRODUCTION_URL"] || "https://as.frenimies-lab.dev"

  tester = ProductionTester.new(url, options)
  exit tester.run
end
