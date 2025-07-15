# frozen_string_literal: true

require "rspec/core/rake_task"
require "cucumber/rake/task"

# RSpec task
RSpec::Core::RakeTask.new(:spec)

# Cucumber tasks
Cucumber::Rake::Task.new(:features) do |t|
  t.cucumber_opts = "--format pretty"
end

namespace :cucumber do
  desc "Run Cucumber tests in CI mode (cassettes only)"
  task :ci do
    ENV["CI"] = "true"
    ENV["VCR_RECORD_MODE"] = "none"
    Rake::Task["features"].invoke
  end
  
  desc "Run Cucumber tests and record new VCR cassettes"
  task :record do
    ENV["VCR_RECORD_MODE"] = "new_episodes"
    Rake::Task["features"].invoke
  end
  
  desc "Run Cucumber tests and re-record ALL VCR cassettes"
  task :rerecord do
    ENV["VCR_RECORD_MODE"] = "all"
    Rake::Task["features"].invoke
  end
end

# Default task runs all tests
task default: [:spec, :features]

desc "Run all tests (RSpec and Cucumber)"
task test: [:spec, :features]