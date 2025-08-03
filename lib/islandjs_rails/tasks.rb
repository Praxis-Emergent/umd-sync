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

  desc "Build IslandJS webpack bundle for production"
  task :build => :environment do
    puts "🔨 Building IslandJS webpack bundle for production..."
    
    # Check if yarn is available
    unless system('which yarn > /dev/null 2>&1')
      puts "❌ yarn not found. Please install yarn first."
      exit 1
    end
    
    # Check if webpack-cli is available and install if missing
    unless system('yarn list webpack-cli > /dev/null 2>&1')
      puts "⚠️  webpack-cli not found, installing..."
      unless system('yarn add --dev webpack-cli@^5.1.4')
        puts "❌ Failed to install webpack-cli"
        exit 1
      end
      puts "✓ webpack-cli installed"
    end
    
    # Set production environment
    ENV['NODE_ENV'] = 'production'
    
    # Run webpack build
    puts "📦 Running webpack build..."
    success = system('yarn build')
    
    if success
      puts "✅ IslandJS bundle built successfully!"
                        puts "📁 Bundle location: public/islands_bundle.js"
                        puts "📄 Manifest location: public/islands_manifest.json"
      puts ""
      puts "🚀 Ready for deployment!"
      puts "💡 Commit these assets to git for production deployment:"
                        puts "   git add public/islands_*"
      puts "   git commit -m 'Build IslandJS assets for production'"
    else
      puts "❌ Build failed!"
      puts "🔍 Check your webpack configuration and dependencies"
      puts "💡 Try running: yarn install"
      exit 1
    end
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
    puts "Global name overrides: #{config.global_name_overrides.size} configured"
  end

  desc "Show IslandJS version"
  task :version do
    puts "IslandjsRails #{IslandjsRails::VERSION}"
  end
end

# Alias tasks for convenience
namespace :islands do
  task :init => 'islandjs:init'
  task :install => 'islandjs:install'
  task :update => 'islandjs:update'
  task :remove => 'islandjs:remove'
  task :sync => 'islandjs:sync'
  task :status => 'islandjs:status'
  task :clean => 'islandjs:clean'
  task :build => 'islandjs:build'
  task :config => 'islandjs:config'
  task :version => 'islandjs:version'
end
