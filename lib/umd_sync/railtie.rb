require 'rails/railtie'

module UmdSync
  class Railtie < Rails::Railtie
    railtie_name :umd_sync

    rake_tasks do
      load 'umd_sync/tasks.rb'
      
      # Hook into assets:precompile for production deploys
      if Rake::Task.task_defined?('assets:precompile')
        Rake::Task['assets:precompile'].enhance(['umd_sync:build'])
      end
    end

    # Auto-include helpers in Rails
    initializer 'umd_sync.helpers' do
      ActiveSupport.on_load(:action_view) do
        include UmdSync::RailsHelpers
        Rails.logger&.debug "UmdSync: Helpers loaded successfully" if Rails.env.development?
      end
    end
    
    # Ensure helpers are available in ApplicationController as well
    initializer 'umd_sync.controller_helpers' do
      ActiveSupport.on_load(:action_controller) do
        helper UmdSync::RailsHelpers
      end
    end

    # Show welcome message on first installation
    initializer 'umd_sync.welcome_message', before: 'initialize_logger' do
      if Rails.env.development?
        Rails.application.config.after_initialize do
          show_welcome_message_if_needed
        end
      end
    end

    # Add development warning if UMD partials are missing
    initializer 'umd_sync.development_warnings', after: 'initialize_logger' do
      if Rails.env.development? && File.exist?(Rails.root.join('package.json'))
        Rails.application.config.after_initialize do
          UmdSync.core.send(:installed_packages).each do |package_name|
            next unless UmdSync.core.send(:supported_package?, package_name)
            
            partial_path = UmdSync.core.send(:partial_path_for, package_name)
            unless File.exist?(partial_path)
              Rails.logger.warn "UmdSync: Missing UMD partial for #{package_name}. Run: rails umd_sync:sync"
            end
          end
        end
      end
    end

    private

    def show_welcome_message_if_needed
      flag_file = Rails.root.join('tmp', '.umd_sync_welcomed')
      return if File.exist?(flag_file)
      
      # Create the flag file to show this only once
      FileUtils.mkdir_p(File.dirname(flag_file))
      File.write(flag_file, Time.current.to_s)
      
      puts <<~WELCOME

        📦 UmdSync Installed 📦

        Next Step: rails umd_sync:init

        Then install available UMD libraries:
          rails "umd_sync:install[react,18.3.1]"
          rails "umd_sync:install[vue,3.3.4]"
          rails "umd_sync:install[lodash,4.17.21]"

      WELCOME
    end
  end
end 