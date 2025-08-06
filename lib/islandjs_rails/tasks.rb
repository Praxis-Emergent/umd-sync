require 'rake'

namespace :islandjs do
  desc "Initialize IslandJS in this Rails project"
  task :init => :environment do
    IslandjsRails.init!
  end

  desc "Install a JavaScript island package"
  task :install, [:package_name, :version] => :environment do |t, args|
    package_name = args[:package_name]
    version = args[:version]
    
    if package_name.nil?
      puts "❌ Package name is required"
      puts "Usage: rails \"islandjs:install[react,18.3.1]\""
      exit 1
    end
    
    IslandjsRails.install!(package_name, version)
  end

  desc "Update a JavaScript island package"
  task :update, [:package_name, :version] => :environment do |t, args|
    package_name = args[:package_name]
    version = args[:version]
    
    if package_name.nil?
      puts "❌ Package name is required"
      puts "Usage: rails \"islandjs:update[react,18.3.1]\""
      exit 1
    end
    
    IslandjsRails.update!(package_name, version)
  end

  desc "Remove a JavaScript island package"
  task :remove, [:package_name] => :environment do |t, args|
    package_name = args[:package_name]
    
    if package_name.nil?
      puts "❌ Package name is required"
      puts "Usage: rails \"islandjs:remove[react]\""
      exit 1
    end
    
    IslandjsRails.remove!(package_name)
  end

  desc "Sync all JavaScript island packages with current package.json"
  task :sync => :environment do
    IslandjsRails.sync!
  end

  desc "Show status of all JavaScript island packages"
  task :status => :environment do
    IslandjsRails.status!
  end

  desc "Clean all island partials and reset webpack externals"
  task :clean => :environment do
    IslandjsRails.clean!
  end

  desc "Show IslandJS configuration"
  task :config => :environment do
    config = IslandjsRails.configuration
            puts "📊 IslandjsRails Configuration"
    puts "=" * 40
    puts "Package.json path: #{config.package_json_path}"
    puts "Partials directory: #{config.partials_dir}"
    puts "Webpack config path: #{config.webpack_config_path}"
    puts "Supported CDNs: #{config.supported_cdns.join(', ')}"
    puts "Built-in global name overrides: #{IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES.size} available"
  end

  desc "Show IslandJS version"
  task :version do
    puts "IslandjsRails #{IslandjsRails::VERSION}"
  end

  namespace :vendor do
    desc "Rebuild combined vendor bundle (for :external_combined mode)"
    task :rebuild_combined => :environment do
      IslandjsRails.vendor_manager.rebuild_combined_bundle!
    end

    desc "Show vendor configuration and status"
    task :status => :environment do
      config = IslandjsRails.configuration
      puts "📦 IslandJS Vendor Status"
      puts "=" * 40
      puts "Mode: #{config.vendor_script_mode}"
      puts "Vendor directory: #{config.vendor_dir}"
      puts "Combined basename: #{config.combined_basename}"
      puts "Vendor order: #{config.vendor_order.join(', ')}"
      
      # Show manifest info
      manifest_path = config.vendor_manifest_path
      if File.exist?(manifest_path)
        require 'json'
        manifest = JSON.parse(File.read(manifest_path))
        puts "\nInstalled libraries: #{manifest['libs'].length}"
        manifest['libs'].each do |lib|
          puts "  • #{lib['name']}@#{lib['version']} (#{lib['file']})"
        end
        
        if manifest['combined']
          puts "\nCombined bundle: #{manifest['combined']['file']} (#{manifest['combined']['size_kb']}KB)"
        end
      else
        puts "\nNo vendor manifest found"
      end
    end
  end
end


