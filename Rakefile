# frozen_string_literal: true

require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

namespace :docs do
  desc "Build the documentation site"
  task :build do
    require "jekyll"
    Jekyll::Commands::Build.process(
      source: File.expand_path("docs", __dir__),
      destination: File.expand_path("_site", __dir__)
    )
  end
end

task default: %i[test rubocop]
