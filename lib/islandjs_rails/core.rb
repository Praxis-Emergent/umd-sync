require 'json'
require 'open3'
require 'net/http'
require 'uri'
require 'fileutils'

module IslandjsRails
  class Core
    attr_reader :configuration

    def initialize
      @configuration = IslandjsRails.configuration
    end

    # Essential dependencies for IslandJS webpack setup
    ESSENTIAL_DEPENDENCIES = [
      'webpack@^5.88.2',
      'webpack-cli@^5.1.4', 
      'terser-webpack-plugin@^5.3.14',
      'webpack-manifest-plugin@^5.0.1',
      'babel-loader@^9.1.3',
      '@babel/core@^7.23.0',
      '@babel/preset-env@^7.23.0',
      '@babel/preset-react@^7.23.0'
    ].freeze

    # Initialize IslandJS in a Rails project
    def init!
      puts "🏝️ Initializing IslandJS Rails..."
      
      check_node_tools!
      ensure_package_json!
      install_essential_dependencies!
      create_scaffolded_structure!
      
      FileUtils.mkdir_p(configuration.partials_dir)
      puts "✓ Created #{configuration.partials_dir}"
      
      unless File.exist?(configuration.webpack_config_path)
        generate_webpack_config!
        puts "✓ Generated webpack.config.js"
      else
        puts "✓ webpack.config.js already exists"
      end
      
      inject_island_partials_into_layout!
      ensure_node_modules_gitignored!
      
      puts "\n🎉 IslandJS Rails initialized successfully!"
      puts "\n📋 Next steps:"
      puts "1. Install libraries:  rails \"islandjs:install[react,18.3.1]\""
      puts "                       rails \"islandjs:install[react-dom,18.3.1]\"  "
      puts "2. Start dev:          yarn watch"
      puts "3. Use components:     <%= react_component('HelloWorld') %>"
      puts "4. Build for prod:     rails islandjs:build"
      puts "5. Commit assets:      git add public/islandjsRails*"
  
      puts "\n🚀 Rails 8 Ready: Commit your built assets for bulletproof deploys!"
      puts "💡 IslandJS is framework-agnostic - use React, Vue, or any JavaScript library!"
      puts "🎉 Ready to build!"
    end

    # Install a new island package
    def install!(package_name, version = nil)
      puts "📦 Installing island package: #{package_name}"
      
      add_package_via_yarn(package_name, version)
      install_package!(package_name, version)
      
      global_name = detect_global_name(package_name)
      update_webpack_externals(package_name, global_name)
      
      puts "✅ Successfully installed #{package_name}!"
      
      if react_ecosystem_complete?
        activate_react_scaffolding!
      end
    end

    # Update an existing package
    def update!(package_name, version = nil)
      puts "🔄 Updating island package: #{package_name}"
      
      unless package_installed?(package_name)
        puts "❌ Package #{package_name} is not installed"
        exit 1
      end
      
      yarn_update!(package_name, version)
      install_package!(package_name, version)
      
      puts "✅ Successfully updated #{package_name}!"
    end

    # Remove a specific package
    def remove!(package_name)
      puts "🗑️  Removing island package: #{package_name}"
      
      unless package_installed?(package_name)
        puts "❌ Package #{package_name} is not installed"
        exit 1
      end
      
      remove_package_via_yarn(package_name)
      
      partial_path = partial_path_for(package_name)
      if File.exist?(partial_path)
        File.delete(partial_path)
        puts "  ✓ Removed partial: #{File.basename(partial_path)}"
      end
      
      update_webpack_externals
      puts "✅ Successfully removed #{package_name}!"
    end

    # Sync all packages
    def sync!
      puts "🔄 Syncing all island packages..."
      
      packages = installed_packages
      if packages.empty?
        puts "📦 No packages found in package.json"
        return
      end
      
      packages.each do |package_name|
        next unless supported_package?(package_name)
        puts "  📦 Processing #{package_name}..."
        download_and_create_partial!(package_name)
      end
      
      puts "✅ Sync completed!"
    end

    # Show status of all packages
    def status!
      puts "📊 IslandJS Package Status"
      puts "=" * 40
      
      packages = installed_packages
      if packages.empty?
        puts "📦 No packages found in package.json"
        return
      end
      
      packages.each do |package_name|
        version = version_for(package_name)
        has_partial = has_partial?(package_name)
        status_icon = has_partial ? "✅" : "❌"
        puts "#{status_icon} #{package_name}@#{version} #{has_partial ? '(island ready)' : '(missing partial)'}"
      end
    end

    # Clean all partials
    def clean!
      puts "🧹 Cleaning island partials..."
      
      if Dir.exist?(configuration.partials_dir)
        Dir.glob(File.join(configuration.partials_dir, '*.html.erb')).each do |file|
          File.delete(file)
          puts "  ✓ Removed #{File.basename(file)}"
        end
      end
      
      reset_webpack_externals
      puts "✅ Clean completed!"
    end

    # Public methods for external access
    def package_installed?(package_name)
      return false unless File.exist?(configuration.package_json_path)
      
      begin
        package_data = JSON.parse(File.read(configuration.package_json_path))
        dependencies = package_data.dig('dependencies') || {}
        dev_dependencies = package_data.dig('devDependencies') || {}
        
        dependencies.key?(package_name) || dev_dependencies.key?(package_name)
      rescue JSON::ParserError, Errno::ENOENT
        false
      end
    end

    def detect_global_name(package_name, url = nil)
      override = configuration.global_name_overrides[package_name]
      return override if override
      
      if package_name.start_with?('@')
        package_name.gsub(/[@\/\-\.]/, '').split(/(?=[A-Z])/).map(&:capitalize).join.gsub(/^./, &:downcase)
      else
        package_name.split('-').map.with_index { |part, i| i == 0 ? part : part.capitalize }.join
      end
    end

    def version_for(library_name)
      package_data = package_json
      return nil unless package_data
      
      dependencies = package_data.dig('dependencies') || {}
      dev_dependencies = package_data.dig('devDependencies') || {}
      
      version = dependencies[library_name] || dev_dependencies[library_name]
      return nil unless version
      
      version.gsub(/[\^~>=<]/, '')
    end

    def find_working_island_url(package_name, version)
      puts "🔍 Searching for island build..."
      
      version ||= version_for(package_name)
      return nil unless version
      
      cdn_name = Configuration::SCOPED_PACKAGE_MAPPINGS[package_name] || package_name
      
      configuration.supported_cdns.each do |cdn_base|
        Configuration::ISLAND_PATH_PATTERNS.each do |pattern|
          path = pattern.gsub('{name}', cdn_name.split('/').last)
          url = "#{cdn_base}/#{cdn_name}@#{version}#{path}"
          
          if url_accessible?(url)
            puts "✓ Found island: #{url}"
            return url
          end
        end
      end
      
      puts "❌ No island build found for #{package_name}@#{version}"
      nil
    end

    private

    def react_ecosystem_complete?
      package_installed?('react') && package_installed?('react-dom')
    end

    def activate_react_scaffolding!
      puts "\n🎉 React ecosystem is now complete (React + React-DOM)!"
      
      uncomment_react_imports!
      create_hello_world_component!
      build_bundle!
      offer_demo_route!
    end

    def uncomment_react_imports!
      index_js_path = File.join(Dir.pwd, 'app', 'javascript', 'islandjs', 'index.js')
      return unless File.exist?(index_js_path)
      
      content = File.read(index_js_path)
      
      if content.include?('// import HelloWorld') && content.include?('// window.islandjsRails')
        updated_content = content.gsub(/^\/\/ (import HelloWorld.*|window\.islandjsRails.*)/, '\1')
        File.write(index_js_path, updated_content)
        puts "✓ Uncommented React imports in app/javascript/islandjs/index.js"
      else
        puts "⚠️  index.js has been modified - please add HelloWorld manually"
      end
    end

    def create_hello_world_component!
      components_dir = File.join(Dir.pwd, 'components')
      FileUtils.mkdir_p(components_dir)
      
      hello_world_path = File.join(components_dir, 'HelloWorld.jsx')
      
      if File.exist?(hello_world_path)
        puts "✓ HelloWorld component already exists"
        return
      end
      
      hello_world_content = <<~JSX
        import React from 'react';
        
        const HelloWorld = ({ name = 'World' }) => {
          return (
            <div style={{
              padding: '20px',
              border: '2px solid #4CAF50',
              borderRadius: '8px',
              backgroundColor: '#f9f9f9',
              textAlign: 'center',
              margin: '20px 0'
            }}>
              <h2 style={{ color: '#4CAF50', margin: '0 0 10px 0' }}>
                🏝️ IslandJS Rails
              </h2>
              <p style={{ margin: '0', fontSize: '18px' }}>
                Hello, {name}! Your React island is working perfectly.
              </p>
              <p style={{ margin: '10px 0 0 0', fontSize: '14px', color: '#666' }}>
                Edit this component in <code>components/HelloWorld.jsx</code>
              </p>
            </div>
          );
        };
        
        export default HelloWorld;
      JSX
      
      File.write(hello_world_path, hello_world_content)
      puts "✓ Created HelloWorld component at components/HelloWorld.jsx"
    end
  end
end

# Load additional core methods
require_relative 'core_methods'
