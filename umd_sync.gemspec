require_relative "lib/umd_sync/version"

Gem::Specification.new do |spec|
  spec.name          = "umd_sync"
  spec.version       = UmdSync::VERSION
  spec.authors       = ["Eric Arnold"]
  spec.email         = ["ericarnold00+praxisemergent@gmail.com"]

  spec.summary       = "Simplified UMD dependency management for Rails applications"
  spec.description   = "UmdSync automates UMD (Universal Module Definition) dependency management for Rails. Download UMD builds from CDNs, integrate them with ERB partials, and render React components with Turbo-compatible lifecycle management."
  spec.homepage      = "https://github.com/umd-sync/umd_sync"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/umd-sync/umd_sync"
  spec.metadata["changelog_uri"] = "https://github.com/umd-sync/umd_sync/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile]) ||
        f.end_with?(".gem")
    end
  end
  
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Rails integration
  spec.add_dependency "rails", ">= 7.0"
  spec.add_dependency "thor", "~> 1.0"
  
  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "webmock", "~> 3.0"
  spec.add_development_dependency "vcr", "~> 6.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
end 