require 'rails/railtie'

module IslandjsRails
  class Railtie < Rails::Railtie
    railtie_name :islandjs_rails

    rake_tasks do
      load File.expand_path('tasks.rb', __dir__)
    end

    initializer 'islandjs_rails.helpers' do
      ActiveSupport.on_load(:action_view) do
        include IslandjsRails::RailsHelpers
      end
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
