require 'rails/railtie'

module UmdSync
  class Railtie < Rails::Railtie
    railtie_name :umd_sync

    rake_tasks do
      load 'umd_sync/tasks.rb'
    end

    # Auto-include helpers in Rails
    initializer 'umd_sync.helpers' do
      ActiveSupport.on_load(:action_view) do
        include UmdSync::RailsHelpers
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
  end
end 