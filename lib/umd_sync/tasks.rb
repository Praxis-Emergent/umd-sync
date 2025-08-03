namespace :umd_sync do
  desc 'Initialize UmdSync in this Rails project'
  task :init do
    UmdSync.init!
  end

  desc 'Install a UMD package (usage: rails umd_sync:install[react])'
  task :install, [:package_name, :version] do |t, args|
    package_name = args[:package_name]
    version = args[:version]
    
    if package_name.blank?
      puts "❌ Please specify a package name"
      puts "Usage: rails umd_sync:install[react]"
      puts "       rails umd_sync:install[react,18.3.1]"
      exit 1
    end
    
    UmdSync.install!(package_name, version)
  end

  desc 'Update a UMD package (usage: rails umd_sync:update[react])'
  task :update, [:package_name, :version] do |t, args|
    package_name = args[:package_name]
    version = args[:version]
    
    if package_name.blank?
      puts "❌ Please specify a package name"
      puts "Usage: rails umd_sync:update[react]"
      puts "       rails umd_sync:update[react,18.3.1]"
      exit 1
    end
    
    UmdSync.update!(package_name, version)
  end

  desc 'Remove a UMD package (usage: rails umd_sync:remove[react])'
  task :remove, [:package_name] do |t, args|
    package_name = args[:package_name]
    
    if package_name.blank?
      puts "❌ Please specify a package name"
      puts "Usage: rails umd_sync:remove[react]"
      exit 1
    end
    
    UmdSync.remove!(package_name)
  end

  desc 'Sync all UMD packages with current package.json'
  task :sync do
    UmdSync.sync!
  end

  desc 'Show status of all UMD packages'
  task :status do
    UmdSync.status!
  end

  desc 'Clean all UMD partials and reset webpack externals'
  task :clean do
    UmdSync.clean!
  end

  desc 'Show UmdSync configuration'
  task :config do
    config = UmdSync.configuration
    puts "📊 UmdSync Configuration"
    puts "=" * 40
    puts "Package.json path: #{config.package_json_path}"
    puts "Partials directory: #{config.partials_dir}"
    puts "Webpack config path: #{config.webpack_config_path}"
    puts "Supported CDNs: #{config.supported_cdns.join(', ')}"
    puts "Global name overrides: #{config.global_name_overrides.size} configured"
  end

  desc 'Build UmdSync webpack bundle for production'
  task :build do
    puts "🔨 Building UmdSync webpack bundle..."
    
    unless File.exist?('package.json')
      puts "❌ No package.json found. Run: rails umd_sync:init"
      exit 1
    end
    
    unless File.exist?('webpack.config.js')
      puts "❌ No webpack.config.js found. Run: rails umd_sync:init"
      exit 1
    end
    
    # Check for yarn or npm
    if system('which yarn > /dev/null 2>&1')
      success = system('NODE_ENV=production yarn build')
    elsif system('which npm > /dev/null 2>&1')
      success = system('NODE_ENV=production npm run build')
    else
      puts "❌ Neither yarn nor npm found. Please install Node.js and yarn/npm."
      exit 1
    end
    
    if success
      puts "✅ UmdSync bundle built successfully!"
      puts "📦 Assets ready for deployment in /public/"
    else
      puts "❌ Build failed. Check your webpack configuration."
      exit 1
    end
  end
end 