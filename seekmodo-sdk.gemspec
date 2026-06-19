# frozen_string_literal: true

require "pathname"

Gem::Specification.new do |spec|
  spec.name = "seekmodo-sdk"
  spec.version = Seekmodo::Sdk::VERSION
  spec.authors = ["Seekmodo"]
  spec.email = ["support@seekmodo.com"]

  spec.summary = "Seekmodo Ruby SDK — connector, storefront, admin, and MCP clients"
  spec.description = "Ruby SDK for the Seekmodo MCP gateway with HMAC connector transport, JWT storefront client, admin tools, and JSON-RPC MCP support."
  spec.homepage = "https://seekmodo.com/docs/sdk"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/numinix/seekmodo-ruby-sdk"

  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.start_with?("spec/")
    end
  rescue StandardError
    Dir["lib/**/*", "README.md", "LICENSE", ".rubocop.yml", ".gitignore"]
  end

  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "faraday", ">= 2.0"
  spec.add_dependency "jwt", ">= 2.7"

  spec.add_development_dependency "rspec", "~> 3.13"
  spec.add_development_dependency "rubocop", "~> 1.60"
  spec.add_development_dependency "rubocop-rspec", "~> 2.25"
  spec.add_development_dependency "webmock", "~> 3.23"
end
