require_relative "lib/islandjs_rails/version"

Gem::Specification.new do |spec|
  spec.name          = "islandjs-rails"
  spec.version       = IslandjsRails::VERSION
  spec.authors       = ["Eric Arnold"]
  spec.email         = ["ericarnold00+praxisemergent@gmail.com"]

  spec.summary       = "JavaScript islands for Rails with zero webpack complexity"
  spec.description   = "IslandJS Rails enables React, Vue, and other JavaScript islands in Rails apps with zero webpack complexity. Load UMD libraries from CDNs, integrate with ERB partials, and render components with Turbo-compatible lifecycle management."
  spec.homepage      = "https://github.com/praxis-emergent/islandjs-rails"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/praxis-emergent/islandjs-rails"
  spec.metadata["changelog_uri"] = "https://github.com/praxis-emergent/islandjs-rails/blob/main/CHANGELOG.md"

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

  # Post-install message
  spec.post_install_message = <<~MSG
    
    🏝️ IslandJS Rails installed successfully!
    
    📋 Next step: Initialize IslandJS in your Rails app

        rails islandjs:init
    
  MSG

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
