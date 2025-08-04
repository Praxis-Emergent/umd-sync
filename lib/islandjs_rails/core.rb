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
      puts "🚀 Initializing IslandjsRails..."
      
      # Step 1: Check for required tools
      check_node_tools!
      
      # Step 2: Ensure package.json exists
      ensure_package_json!
      
      # Step 3: Install essential webpack dependencies
      install_essential_dependencies!
      
      # Step 4: Create scaffolded structure
      create_scaffolded_structure!
      
      # Step 5: Create directories
      FileUtils.mkdir_p(configuration.partials_dir)
      puts "✓ Created #{configuration.partials_dir}"
      
      # Step 6: Generate webpack config if it doesn't exist
      unless File.exist?(configuration.webpack_config_path)
        generate_webpack_config!
        puts "✓ Generated webpack.config.js"
      else
        puts "✓ webpack.config.js already exists"
      end
      
      # Step 7: Auto-inject islands helper into layout
      inject_umd_partials_into_layout!
      
      # Step 8: Add node_modules to .gitignore
      ensure_node_modules_gitignored!
      
      puts "\n🎉 IslandjsRails initialized successfully!"
      puts "\n📋 Next steps:"
      puts "1. Install libraries:  rails \"islandjs:install[react,18.3.1]\""
      puts "                       rails \"islandjs:install[react-dom,18.3.1]\"  "
      puts "2. Start dev:          yarn watch"
      puts "3. Use components:     <%= react_component('HelloWorld') %>"
      puts "4. Build for prod:     rails islandjs:build"
      puts "5. Commit assets:      git add public/islands_*"
  
      puts "\n🚀 Rails 8 Ready: Commit your built assets for bulletproof deploys!"
      puts "💡 IslandjsRails is framework-agnostic - use React, Vue, or any UMD library!"
      puts "🎉 Ready to build!"
    end

    # Install a new island package
    def install!(package_name, version = nil)
      puts "📦 Installing UMD package: #{package_name}"
      
      # Check if React ecosystem was incomplete before this install
      was_react_ecosystem_incomplete = !react_ecosystem_complete?
      
      # Add to package.json via yarn if not present
      add_package_via_yarn(package_name, version) unless package_installed?(package_name)
      
      # Install the UMD
      install_package!(package_name, version)
      
      global_name = detect_global_name(package_name)
      update_webpack_externals(package_name, global_name)
      
      puts "✅ Successfully installed #{package_name}!"
      
      # Auto-scaffold React if ecosystem just became complete
      if was_react_ecosystem_incomplete && react_ecosystem_complete? && 
         (package_name == 'react' || package_name == 'react-dom')
        activate_react_scaffolding!
      end
    end

    # Update an existing package
    def update!(package_name, version = nil)
      puts "🔄 Updating UMD package: #{package_name}"
      
      unless package_installed?(package_name)
        raise IslandjsRails::PackageNotFoundError, "#{package_name} is not installed. Use 'install' instead."
      end
      
      # Update package.json via yarn
      yarn_update!(package_name, version)
      
      # Re-install UMD
      install_package!(package_name)
      
      puts "✅ Successfully updated #{package_name}!"
    end

    # Remove a specific package
    def remove!(package_name)
      puts "🗑️  Removing island package: #{package_name}"
      
      unless package_installed?(package_name)
        raise IslandjsRails::PackageNotFoundError, "Package #{package_name} is not installed"
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
      puts "🔄 Syncing all UMD packages..."
      
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
              puts "📊 IslandjsRails Status"
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
      puts "🧹 Cleaning UMD partials..."
      
      if Dir.exist?(configuration.partials_dir)
        Dir.glob(File.join(configuration.partials_dir, '*.html.erb')).each do |file|
          File.delete(file)
          puts "  ✓ Removed #{File.basename(file)}"
        end
        # Remove directory if it's now empty
        if Dir.empty?(configuration.partials_dir)
          Dir.rmdir(configuration.partials_dir)
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
      # Check configured overrides first
      override = configuration.global_name_overrides[package_name]
      return override if override
      
      # For scoped packages, use the package name part
      clean_name = package_name.include?('/') ? package_name.split('/').last : package_name
      
      # Convert kebab-case to camelCase
      clean_name.split('-').map.with_index { |part, i| i == 0 ? part : part.capitalize }.join
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

    def download_umd_content(url)
      require 'net/http'
      require 'uri'
      
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      unless response.code == '200'
        raise IslandjsRails::Error, "Failed to download UMD from #{url}: #{response.code}"
      end
      
      response.body
    end

    def find_working_umd_url(package_name, version)
      puts "  🔍 Searching for UMD build..."
      
      # Get package name without scope for path patterns
      clean_name = package_name.split('/').last
      
      IslandjsRails::CDN_BASES.each do |cdn_base|
        IslandjsRails::UMD_PATH_PATTERNS.each do |pattern|
          # Replace placeholders in pattern
          path = pattern.gsub('{name}', clean_name)
          url = "#{cdn_base}/#{package_name}@#{version}/#{path}"
          
          if url_accessible?(url)
            puts "  ✓ Found UMD: #{url}"
            
            # Try to detect global name from the UMD content
            global_name = detect_global_name(package_name, url)
            
            return [url, global_name]
          end
        end
      end
      
      puts "  ❌ No UMD build found for #{package_name}@#{version}"
      [nil, nil]
    end

    private

    # Check if a URL is accessible (returns 200 status)
    def url_accessible?(url)
      require 'net/http'
      require 'uri'
      
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      response.code == '200'
    rescue => e
      false
    end
    
    # Check if a package has a partial file
    def has_partial?(package_name)
      File.exist?(partial_path_for(package_name))
    end
    
    # Get global name for a package (used by webpack externals)
    def get_global_name_for_package(package_name)
      detect_global_name(package_name)
    end

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
      index_js_path = File.join(Dir.pwd, 'app', 'javascript', 'islands', 'index.js')
      return unless File.exist?(index_js_path)
      
      content = File.read(index_js_path)
      
      # Check if this looks like our commented template
      if content.include?('// import HelloWorld from') && content.include?('// HelloWorld')
        # Uncomment the import
        updated_content = content.gsub('// import HelloWorld from', 'import HelloWorld from')
        # Uncomment the export within the window.islandjsRails object
        updated_content = updated_content.gsub(/(\s+)\/\/ HelloWorld/, '\1HelloWorld')
        
        File.write(index_js_path, updated_content)
        puts "✓ Activated React imports in index.js"
      else
        puts "⚠️  index.js has been modified - please add HelloWorld manually"
      end
    end

    def create_hello_world_component!
      components_dir = File.join(Dir.pwd, 'app', 'javascript', 'islands', 'components')
      FileUtils.mkdir_p(components_dir)
      
      hello_world_path = File.join(components_dir, 'HelloWorld.jsx')
      
      if File.exist?(hello_world_path)
        puts "✓ HelloWorld.jsx already exists"
        return
      end
      
      hello_world_content = <<~JSX
        import React, { useState } from 'react';
        
        const HelloWorld = ({ message = "Hello from IslandjsRails!" }) => {
          const [count, setCount] = useState(0);
          
          return (
            <div style={{
              padding: '20px',
              border: '2px solid #4F46E5',
              borderRadius: '8px',
              backgroundColor: '#F8FAFC',
              textAlign: 'center',
              fontFamily: 'system-ui, sans-serif'
            }}>
              <h2 style={{ color: '#4F46E5', margin: '0 0 16px 0' }}>
                🏝️ React + IslandjsRails
              </h2>
              <p style={{ margin: '0 0 16px 0', fontSize: '18px' }}>
                {message}
              </p>
              <button
                onClick={() => setCount(count + 1)}
                style={{
                  padding: '8px 16px',
                  backgroundColor: '#4F46E5',
                  color: 'white',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: 'pointer',
                  fontSize: '16px'
                }}
              >
                Clicked {count} times
              </button>
            </div>
          );
        };
        
        export default HelloWorld;
      JSX
      
      File.write(hello_world_path, hello_world_content)
      puts "✓ Created HelloWorld.jsx component"
    end
  end
end

# Load additional core methods
require_relative 'core_methods'
