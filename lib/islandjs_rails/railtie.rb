require 'rails/railtie'

module IslandjsRails
  class Railtie < Rails::Railtie
    railtie_name :islandjs_rails

    # Add helpers to ActionView
    initializer "islandjs_rails.view_helpers" do
      ActiveSupport.on_load :action_view do
        include IslandjsRails::RailsHelpers
      end
    end

    # Rails 8 asset compilation integration
    initializer "islandjs_rails.asset_compilation" do |app|
      if app.config.respond_to?(:assets) && app.config.assets.respond_to?(:precompile)
        # Add islands assets to precompile list
        app.config.assets.precompile += %w[
          islands_bundle.js
          islands_manifest.json
          islands/**/*.js
        ]
      end
    end

    # CSP configuration for Rails 8
    initializer "islandjs_rails.content_security_policy" do |app|
      if app.config.respond_to?(:content_security_policy)
        app.config.content_security_policy do |policy|
          # Allow islands assets and UMD libraries
          if Rails.env.development?
            policy.script_src :self, :unsafe_inline, 'https://unpkg.com', 'https://cdn.jsdelivr.net'
          else
            policy.script_src :self, 'https://unpkg.com', 'https://cdn.jsdelivr.net'
          end
          
          # Connect-src for potential API calls from components
          policy.connect_src :self
        end
        
        # Add nonce support for production inline scripts
        unless Rails.env.development?
          app.config.content_security_policy_nonce_generator = -> request { SecureRandom.base64(16) }
        end
      end
    end

    # Import maps integration for Rails 8
    initializer "islandjs_rails.import_maps" do |app|
      if defined?(Importmap)
        # Register islands bundle with import maps if available
        app.config.to_prepare do
          if Rails.application.importmap&.respond_to?(:pin)
            Rails.application.importmap.pin "islands", to: "islands_bundle.js"
          end
        end
      end
    end

    # Propshaft integration for Rails 8 asset pipeline
    initializer "islandjs_rails.propshaft" do |app|
      if defined?(Propshaft)
        app.config.to_prepare do
          # Ensure islands assets are included in Propshaft manifest
          if Rails.application.config.assets.respond_to?(:paths)
            Rails.application.config.assets.paths << Rails.root.join("public/islands")
          end
        end
      end
    end

    # Rake tasks for asset compilation
    rake_tasks do
      load "islandjs_rails/tasks.rb"
    end

    # Development-only warnings and checks
    initializer 'islandjs_rails.development_warnings', after: :load_config_initializers do
      if Rails.env.development?
        # Check for common setup issues
        Rails.application.config.after_initialize do
          check_development_setup
        end
      end
    end

    private

    def check_development_setup
      # Check if package.json exists
      unless File.exist?(Rails.root.join('package.json'))
        Rails.logger.warn "IslandJS: package.json not found. Run 'rails islandjs:init' to set up."
        return
      end

      # Check if webpack config exists
      unless File.exist?(Rails.root.join('webpack.config.js'))
        Rails.logger.warn "IslandJS: webpack.config.js not found. Run 'rails islandjs:init' to set up."
        return
      end

      # Check if yarn is available
      unless system('which yarn > /dev/null 2>&1')
        Rails.logger.warn "IslandJS: yarn not found. Please install yarn for package management."
        return
      end

      # Check if essential webpack dependencies are installed
      essential_deps = ['webpack', 'webpack-cli', '@babel/core']
      missing_deps = essential_deps.select do |dep|
        !system("yarn list #{dep} > /dev/null 2>&1")
      end

      unless missing_deps.empty?
        Rails.logger.warn "IslandJS: Missing dependencies: #{missing_deps.join(', ')}. Run 'rails islandjs:init' to install."
      end
    end
  end
end
