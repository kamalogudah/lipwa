# frozen_string_literal: true

require_relative "lib/lipwa/version"

Gem::Specification.new do |spec|
  spec.name = "lipwa"
  spec.version = Lipwa::VERSION
  spec.authors = ["Paul Oguda"]
  spec.email = ["mcpaul2058@gmail.com"]

  spec.summary = "Unified Ruby gem for African payment providers, starting with M-Pesa Daraja."
  spec.description = "Lipwa is a unified Ruby gem for accepting and disbursing payments across " \
                      "African payment providers -- mobile money, bank APIs, and (eventually) " \
                      "card rails -- behind one consistent, capability-based interface. It " \
                      "currently ships a full integration with Safaricom's M-Pesa Daraja API: " \
                      "STK Push, C2B, B2C/B2B disbursements, and inbound webhook handling."
  spec.homepage = "https://github.com/kamalogudah/lipwa"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"
  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/kamalogudah/lipwa"
  spec.metadata["changelog_uri"] = "https://github.com/kamalogudah/lipwa/blob/main/CHANGELOG.md"

  # Package only tracked runtime files and release documentation.
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).select do |f|
      f.start_with?("lib/", "exe/") || %w[LICENSE.txt README.md CHANGELOG.md].include?(f)
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "base64", "~> 0.2"
  spec.add_dependency "dry-configurable", "~> 1.0"
  spec.add_dependency "dry-container", "~> 0.11"
  spec.add_dependency "dry-monads", "~> 1.6"
  spec.add_dependency "dry-struct", "~> 1.6"
  spec.add_dependency "dry-types", "~> 1.7"
  spec.add_dependency "dry-validation", "~> 1.10"
  spec.add_dependency "faraday", "~> 2.7"
  spec.add_dependency "faraday-retry", "~> 2.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
