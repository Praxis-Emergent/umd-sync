require 'json'

module UmdSync
  class Core
    attr_reader :configuration

    def initialize
      @configuration = UmdSync.configuration
    end

    # Essential dependencies for UmdSync webpack setup
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

    # Initialize UmdSync in a Rails project
    def init!
      puts "🚀 Initializing UmdSync..."
      
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
      
      # Step 7: Auto-inject UMD helper into layout
      inject_umd_partials_into_layout!
      
      # Step 8: Add node_modules to .gitignore
      ensure_node_modules_gitignored!
      
      puts "\n✅ UmdSync initialized successfully!"
      puts "\n📋 Next steps:"
      puts "1. Install libraries:  rails \"umd_sync:install[react,18.3.1]\""
      puts "                       rails \"umd_sync:install[react-dom,18.3.1]\""  
      puts "2. Start dev:          yarn watch"
      puts "3. Use components:     <%= react_component('HelloWorld') %>"
      puts "\n💡 UmdSync is framework-agnostic - use React, Vue, or any UMD library!"
      puts "🎉 Ready to build!"
    end

    private

    # Check if both React and React-DOM are installed  
    def react_ecosystem_complete?
      package_installed?('react') && package_installed?('react-dom')
    end

    # Activate React scaffolding when React ecosystem becomes complete
    def activate_react_scaffolding!
      puts "\n🎉 React ecosystem is now complete (React + React-DOM)!"
      
      # 1. Uncomment React imports in index.js if they match our template
      uncomment_react_imports!
      
      # 2. Create HelloWorld component
      create_hello_world_component!
      
      # 3. Offer demo route
      offer_demo_route!
    end

    # Uncomment React imports in index.js if they match our commented template
    def uncomment_react_imports!
      index_js_path = File.join(Dir.pwd, 'app', 'javascript', 'umd_sync', 'index.js')
      return unless File.exist?(index_js_path)
      
      content = File.read(index_js_path)
      
      # Check if this looks like our commented template
      if content.include?('// import HelloWorld from') && content.include?('// HelloWorld')
        # Uncomment the import
        updated_content = content.gsub('// import HelloWorld from', 'import HelloWorld from')
        # Uncomment the export
        updated_content = updated_content.gsub('// HelloWorld', 'HelloWorld')
        
        File.write(index_js_path, updated_content)
        puts "✓ Activated React imports in index.js"
      else
        puts "⚠️  index.js has been modified - please add HelloWorld manually"
      end
    end

    # Create HelloWorld React component
    def create_hello_world_component!
      components_dir = File.join(Dir.pwd, 'app', 'javascript', 'umd_sync', 'components')
      hello_world_path = File.join(components_dir, 'HelloWorld.jsx')
      
      if File.exist?(hello_world_path)
        puts "✓ HelloWorld.jsx already exists"
        return
      end
      
      hello_world_content = <<~JSX
        import React, { useState } from 'react';
        
        const HelloWorld = ({ message = "Hello from UmdSync!" }) => {
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
                🤝 React + UmdSync
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
              <p style={{ 
                marginTop: '16px', 
                fontSize: '14px', 
                color: '#6B7280' 
              }}>
                🎉 Your React component is working!
              </p>
            </div>
          );
        };
        
        export default HelloWorld;
      JSX
      
      File.write(hello_world_path, hello_world_content)
      puts "✓ Created HelloWorld.jsx component"
    end

    # Offer to create a demo route for React showcase
    def offer_demo_route!
      # Check if demo route already exists
      if demo_route_exists?
        puts "✓ Demo route already exists at /umd-sync/react"
        return
      end
      
      print "\n❓ Would you like to create a demo route at /umd-sync/react to showcase your HelloWorld component? (y/n): "
      answer = STDIN.gets.chomp.downcase
      
      if answer == 'y' || answer == 'yes'
        create_demo_route!
        puts "\n🎉 Demo route created! Visit http://localhost:3000/umd-sync/react to see your React component in action."
        puts "💡 You can remove it later by deleting the route, controller, and view manually."
      else
        puts "\n💡 No problem! Here's how to render your HelloWorld component manually:"
        puts "   In any view: <%= react_component('HelloWorld') %>"
        puts "   Don't forget to: yarn build && rails server"
      end
    end

    # Check for npm and yarn availability
    def check_node_tools!
      unless system('which npm > /dev/null 2>&1')
        puts "❌ npm not found. Please install Node.js and npm first."
        puts "   Visit: https://nodejs.org/"
        exit 1
      end
      
      unless system('which yarn > /dev/null 2>&1')
        puts "❌ yarn not found. Please install yarn first."
        puts "   npm install -g yarn"
        exit 1
      end
      
      puts "✓ npm and yarn are available"
    end

    # Ensure package.json exists, create if missing
    def ensure_package_json!
      package_json_path = File.join(Dir.pwd, 'package.json')
      
      if File.exist?(package_json_path)
        puts "✓ package.json already exists"
        return
      end
      
      puts "📝 Creating package.json..."
      
      # Create basic package.json
      basic_package_json = {
        "name" => File.basename(Dir.pwd),
        "version" => "1.0.0",
        "private" => true,
        "scripts" => {
          "build" => "NODE_ENV=production webpack",
          "build:dev" => "NODE_ENV=development webpack",
          "watch" => "NODE_ENV=development webpack --watch"
        },
        "dependencies" => {},
        "devDependencies" => {}
      }
      
      File.write(package_json_path, JSON.pretty_generate(basic_package_json))
      puts "✓ Created package.json"
    end

    # Install essential webpack and babel dependencies
    def install_essential_dependencies!
      puts "📦 Installing essential webpack dependencies..."
      
      # Check which dependencies are already installed
      missing_deps = ESSENTIAL_DEPENDENCIES.select do |dep|
        package_name = dep.split('@').first
        !package_installed?(package_name)
      end
      
      if missing_deps.empty?
        puts "✓ All essential dependencies already installed"
        return
      end
      
      puts "  Installing: #{missing_deps.join(', ')}"
      
      # Install missing dependencies
      cmd = "yarn add --dev #{missing_deps.join(' ')}"
      success = system(cmd)
      
      unless success
        puts "❌ Failed to install dependencies"
        exit 1
      end
      
      puts "✓ Installed essential webpack dependencies"
    end

    # Create scaffolded app/javascript/umd_sync structure
    def create_scaffolded_structure!
      puts "🏗️  Creating scaffolded structure..."
      
      # Create app/javascript/umd_sync directory
      umd_sync_dir = File.join(Dir.pwd, 'app', 'javascript', 'umd_sync')
      components_dir = File.join(umd_sync_dir, 'components')
      
      FileUtils.mkdir_p(components_dir)
      
      # Create index.js entry point
      index_js_path = File.join(umd_sync_dir, 'index.js')
      unless File.exist?(index_js_path)
        index_content = <<~JS
          // UmdSync Entry Point
          // Import your JavaScript modules here
          // import HelloWorld from './components/HelloWorld';

          export default {
           // HelloWorld
          };
        JS
        
        File.write(index_js_path, index_content)
        puts "✓ Created app/javascript/umd_sync/index.js"
      else
        puts "✓ app/javascript/umd_sync/index.js already exists"
      end
      
      # Create .gitkeep in components directory (framework-agnostic)
      gitkeep_path = File.join(components_dir, '.gitkeep')
      unless File.exist?(gitkeep_path)
        File.write(gitkeep_path, '')
        puts "✓ Created app/javascript/umd_sync/components/.gitkeep"
      else
        puts "✓ components/.gitkeep already exists"
      end
    end

    # Automatically inject UMD helper into Rails layout
    def inject_umd_partials_into_layout!
      layout_path = File.join(Dir.pwd, 'app', 'views', 'layouts', 'application.html.erb')
      
      unless File.exist?(layout_path)
        puts "⚠️  Layout file not found: #{layout_path}"
        puts "   Please add manually to your layout:"
        puts "   <%= umd_sync %>"
        return
      end
      
      content = File.read(layout_path)
      
      # Check if already injected (idempotent)
      if content.include?('umd_partials') && content.include?('umd_bundle_script') || content.include?('umd_sync')
        puts "✓ UMD helper already present in layout"
        return
      end
      
      # Find the closing </head> tag and inject before it with proper indentation
      if match = content.match(/^(\s*)<\/head>/i)
        indent = match[1] # Capture the indentation
        umd_injection = <<~ERB.chomp
          
          #{indent}<!-- UmdSync: Auto-injected -->
          #{indent}<%= umd_sync %>
        ERB
        
        # Inject before </head> with proper indentation
        updated_content = content.gsub(/^(\s*)<\/head>/i, "#{umd_injection}\n\\1</head>")
        File.write(layout_path, updated_content)
        puts "✓ Auto-injected UMD helper into app/views/layouts/application.html.erb"
      else
        puts "⚠️  Could not find </head> tag in layout"
        puts "   Please add manually to your layout:"
        puts "   <%= umd_sync %>"
      end
    end

    # Ensure node_modules is in .gitignore
    def ensure_node_modules_gitignored!
      gitignore_path = File.join(Dir.pwd, '.gitignore')
      
      unless File.exist?(gitignore_path)
        puts "⚠️  .gitignore not found, creating one..."
        File.write(gitignore_path, "/node_modules\n")
        puts "✓ Created .gitignore with /node_modules"
        return
      end
      
      content = File.read(gitignore_path)
      
      # Check if node_modules is already ignored (various patterns)
      if content.match?(/^\/node_modules\s*$/m) || 
         content.match?(/^node_modules\/?\s*$/m) ||
         content.match?(/^\*\*\/node_modules\/?\s*$/m)
        puts "✓ node_modules already in .gitignore"
        return
      end
      
      # Add /node_modules to .gitignore
      File.write(gitignore_path, content + "\n# UmdSync: Node.js dependencies\n/node_modules\n")
      puts "✓ Added /node_modules to .gitignore"
    end

    public

    # Install a new UMD package
    def install!(package_name, version = nil)
      puts "📦 Installing UMD package: #{package_name}"
      
      # Check if React ecosystem was incomplete before this install
      was_react_ecosystem_incomplete = !react_ecosystem_complete?
      
      # Add to package.json via yarn if not present
      add_package_via_yarn(package_name, version) unless package_installed?(package_name)
      
      # Install the UMD
      install_package!(package_name, version)
      
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
        raise PackageNotFoundError, "#{package_name} is not installed. Use 'install' instead."
      end
      
      # Update package.json via yarn
      yarn_update!(package_name, version)
      
      # Re-install UMD
      install_package!(package_name)
      
      puts "✅ Successfully updated #{package_name}!"
    end

    # Sync all packages (re-download UMDs for current package.json versions)
    def sync!
      puts "🔄 Syncing all UMD packages..."
      
      installed_packages.each do |package_name|
        if supported_package?(package_name)
          puts "\n📦 Processing #{package_name}..."
          download_and_create_partial!(package_name)
        end
      end
      
      update_webpack_externals
      puts "\n✅ Sync completed!"
    end

    # Show status of all UMD packages
    def status!
      puts "📊 UmdSync Status"
      puts "=" * 50
      
      installed_packages.each do |package_name|
        next unless supported_package?(package_name)
        
        version = version_for(package_name)
        partial_path = partial_path_for(package_name)
        has_partial = File.exist?(partial_path)
        
        status_icon = has_partial ? "✅" : "❌"
        puts "#{status_icon} #{package_name}@#{version} #{has_partial ? '(UMD ready)' : '(missing partial)'}"
      end
    end

    # Remove a specific package
    def remove!(package_name)
      puts "🗑️  Removing UMD package: #{package_name}"
      
      unless package_installed?(package_name)
        raise PackageNotFoundError, "#{package_name} is not installed."
      end
      
      # Remove from package.json via yarn
      remove_package_via_yarn(package_name)
      
      # Remove the partial file
      partial_path = partial_path_for(package_name)
      if File.exist?(partial_path)
        File.delete(partial_path)
        puts "  ✓ Removed partial: #{File.basename(partial_path)}"
      end
      
      # Update webpack externals to remove this package
      update_webpack_externals
      
      puts "✅ Successfully removed #{package_name}!"
    end

    # Clean all UMD partials and reset webpack externals
    def clean!
      puts "🧹 Cleaning UMD partials..."
      
      # Remove all partial files
      if Dir.exist?(configuration.partials_dir)
        Dir.glob(File.join(configuration.partials_dir, '_*.html.erb')).each do |file|
          File.delete(file)
          puts "  ✓ Removed #{File.basename(file)}"
        end
        # Remove directory if it's now empty
        if Dir.empty?(configuration.partials_dir)
          Dir.rmdir(configuration.partials_dir)
        end
      end
      
      # Reset webpack externals
      reset_webpack_externals
      
      puts "✅ Clean completed!"
    end

    # Public methods for testing and external access
    def package_installed?(package_name)
      dependencies = package_json['dependencies'] || {}
      dev_dependencies = package_json['devDependencies'] || {}
      dependencies.key?(package_name) || dev_dependencies.key?(package_name)
    rescue => e
      false
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
      dependencies = package_json['dependencies'] || {}
      dev_dependencies = package_json['devDependencies'] || {}
      
      version = dependencies[library_name] || dev_dependencies[library_name]
      
      return nil if version.nil?
      
      # Clean version string (remove ^, ~, etc.)
      version.gsub(/^[\^~]/, '')
    end

    def find_working_umd_url(package_name, version)
      puts "  🔍 Searching for UMD build..."
      
      # Get package name without scope for path patterns
      clean_name = package_name.split('/').last
      
      CDN_BASES.each do |cdn_base|
        UMD_PATH_PATTERNS.each do |pattern|
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

    def download_umd_content(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      unless response.code == '200'
        raise Error, "Failed to download UMD from #{url}: #{response.code}"
      end
      
      response.body
    end

    def create_partial_file(package_name, umd_content, global_name = nil)
      partial_path = partial_path_for(package_name)
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(partial_path))
      
      # Generate partial content
      partial_content = generate_partial_content(package_name, umd_content, global_name)
      
      File.write(partial_path, partial_content)
    end

    def update_webpack_externals(package_name = nil, global_name = nil)
      webpack_config_path = configuration.webpack_config_path
      return unless File.exist?(webpack_config_path)
      
      content = File.read(webpack_config_path)
      
      # Generate externals for all installed packages with partials
      externals = installed_packages
        .select { |pkg| has_partial?(pkg) }
        .map { |pkg| 
          global_name = get_global_name_for_package(pkg)
          "        \"#{pkg}\": \"#{global_name}\""
        }
        .join(",\n")
      
      externals_block = <<~JS
      externals: {
        // UmdSync managed externals - do not edit manually
#{externals}
      },
      JS
      
      # Replace existing externals block (with or without trailing comma)
      updated_content = content.gsub(
        /externals:\s*\{[^}]*\}(?:,)?/m,
        externals_block.chomp
      )
      
      File.write(webpack_config_path, updated_content)
    end

    private

    def install_package!(package_name, version = nil)
      # Get version from package.json
      actual_version = version_for(package_name)
      
      unless actual_version
        raise PackageNotFoundError, "#{package_name} not found in package.json"
      end
      
      # Try to find working UMD URL
      umd_url, global_name = find_working_umd_url(package_name, actual_version)
      
      unless umd_url
        raise UmdNotFoundError, "No UMD build found for #{package_name}@#{actual_version}. This package may not provide a UMD build."
      end
      
      # Download UMD content
      umd_content = download_umd_content(umd_url)
      
      # Create partial
      create_partial_file(package_name, umd_content, global_name)
      
      # Update webpack externals
      update_webpack_externals(package_name, global_name)
      
      puts "  ✓ Created partial: #{partial_path_for(package_name)}"
      puts "  ✓ Global name: #{global_name}" if global_name
      puts "  ✓ Updated webpack externals"
    end

    # Read package.json and return parsed JSON
    def package_json
      @package_json ||= begin
        if File.exist?(configuration.package_json_path)
          JSON.parse(File.read(configuration.package_json_path))
        else
          {}
        end
      end
    end

    # Get list of installed packages that we might support
    def installed_packages
      (package_json['dependencies'] || {}).keys + (package_json['devDependencies'] || {}).keys
    end

    # Check if package is supported
    def supported_package?(package_name)
      # For now, we try to support any package by attempting UMD detection
      true
    end

    # Get partial file path for a package
    def partial_path_for(package_name)
      # Convert package name to valid partial name (replace special chars)
      safe_name = package_name.gsub(/[@\/]/, '_').gsub(/-/, '_')
      configuration.partials_dir.join("_#{safe_name}.html.erb")
    end

    # Download UMD file and create Rails partial
    def download_and_create_partial!(package_name)
      version = version_for(package_name)
      
      # Try to find working UMD URL
      umd_url, global_name = find_working_umd_url(package_name, version)
      
      unless umd_url
        puts "  ❌ No UMD build found for #{package_name}@#{version}"
        return
      end
      
      # Download UMD content
      umd_content = download_umd_content(umd_url)
      
      # Create partial
      create_partial_file(package_name, umd_content, global_name)
      
      puts "  ✓ Created partial: #{partial_path_for(package_name)}"
    end

    def generate_partial_content(package_name, umd_content, global_name = nil)
      safe_name = package_name.gsub(/[@\/]/, '_').gsub(/-/, '_')
      global_name ||= detect_global_name(package_name)
      
      # Base64 encode the content to completely avoid ERB parsing issues
      require 'base64'
      encoded_content = Base64.strict_encode64(umd_content)
      
      <<~ERB
        <%# #{global_name} UMD Library %>
        <%# Global: #{global_name} %>
        <%# Generated by UmdSync %>
        <script type="text/javascript">
        (function() {
          var script = document.createElement('script');
          script.text = atob('<%= "#{encoded_content}" %>');
          document.head.appendChild(script);
          document.head.removeChild(script);
        })();
        </script>
      ERB
    end

    # Add package via yarn
    def add_package_via_yarn(package_name, version = nil)
      package_spec = version ? "#{package_name}@#{version}" : package_name
      command = "yarn add #{package_spec}"
      
      stdout, stderr, status = Open3.capture3(command, chdir: Rails.root)
      
      unless status.success?
        raise YarnError, "Failed to add #{package_spec}: #{stderr}"
      end
      
      # Reset cached package.json
      @package_json = nil
      
      puts "  ✓ Added to package.json: #{package_spec}"
    end

    # Update package via yarn
    def yarn_update!(package_name, version = nil)
      if version
        add_package_via_yarn(package_name, version) # yarn add with version updates
      else
        command = "yarn upgrade #{package_name}"
        stdout, stderr, status = Open3.capture3(command, chdir: Rails.root)
        
        unless status.success?
          raise YarnError, "Failed to update #{package_name}: #{stderr}"
        end
        
        # Reset cached package.json
        @package_json = nil
        
        puts "  ✓ Updated in package.json: #{package_name}"
      end
    end

    # Remove package via yarn
    def remove_package_via_yarn(package_name)
      command = "yarn remove #{package_name}"
      
      stdout, stderr, status = Open3.capture3(command, chdir: Rails.root)
      
      unless status.success?
        raise YarnError, "Failed to remove #{package_name}: #{stderr}"
      end
      
      # Reset cached package.json
      @package_json = nil
      
      puts "  ✓ Removed from package.json: #{package_name}"
    end

    # Generate webpack.config.js with UMD externals
    def generate_webpack_config!
      webpack_content = <<~JS
        const path = require('path');
        const TerserPlugin = require('terser-webpack-plugin');
        const { WebpackManifestPlugin } = require('webpack-manifest-plugin');
        
        const isProduction = process.env.NODE_ENV === 'production';
        
        module.exports = {
          mode: isProduction ? 'production' : 'development',
          entry: {
            bundle: ['./app/javascript/umd_sync/index.js']
          },
          externals: {
            // UmdSync managed externals - do not edit manually
            // These will be auto-updated by umd-sync
          },
          output: {
            path: path.resolve(__dirname, 'public/assets'),
            filename: '[name].[contenthash].js',
            library: {
              name: 'umd_sync',
              type: 'umd',
              export: 'default'
            },
            globalObject: 'window',
            clean: true,
            publicPath: '/assets/'
          },
          plugins: [
            new WebpackManifestPlugin({
              fileName: 'manifest.json',
              publicPath: '/assets/',
              writeToFileEmit: true
            })
          ],
          optimization: {
            minimize: isProduction,
            minimizer: [new TerserPlugin()]
          },
          module: {
            rules: [
              {
                test: /\.(js|jsx)$/,
                exclude: /node_modules/,
                use: {
                  loader: 'babel-loader',
                  options: {
                    presets: ['@babel/preset-env', '@babel/preset-react']
                  }
                }
              }
            ]
          },
          resolve: {
            extensions: ['.js', '.jsx']
          },
          devtool: isProduction ? false : 'eval-source-map',
          watch: !isProduction,
          watchOptions: {
            ignored: /node_modules/,
            aggregateTimeout: 300
          }
        };
      JS
      
      File.write(configuration.webpack_config_path, webpack_content)
    end
    
    # Check if a URL is accessible (returns 200 status)
    def url_accessible?(url)
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
    
    # Reset webpack externals to empty
    def reset_webpack_externals
      webpack_config_path = configuration.webpack_config_path
      return unless File.exist?(webpack_config_path)
      
      content = File.read(webpack_config_path)
      
      externals_block = <<~JS
      externals: {
        // UmdSync managed externals - do not edit manually
      },
      JS
      
      # Replace existing externals block (with or without trailing comma)
      updated_content = content.gsub(
        /externals:\s*\{[^}]*\}(?:,)?/m,
        externals_block.chomp
      )
      
      File.write(webpack_config_path, updated_content)
      puts "  ✓ Reset webpack externals"
    end

    # Check if demo route already exists
    def demo_route_exists?
      routes_file = File.join(Dir.pwd, 'config', 'routes.rb')
      return false unless File.exist?(routes_file)
      
      content = File.read(routes_file)
      content.include?('umd-sync/react') || content.include?('umd_sync_demo')
    end
    
    # Create demo route, controller, and view
    def create_demo_route!
      create_demo_controller!
      create_demo_view!
      add_demo_route!
    end
    
    # Create the demo controller
    def create_demo_controller!
      controller_dir = File.join(Dir.pwd, 'app', 'controllers')
      FileUtils.mkdir_p(controller_dir)
      
      controller_path = File.join(controller_dir, 'umd_sync_demo_controller.rb')
      
      controller_content = <<~RUBY
        class UmdSyncDemoController < ApplicationController
          def react
            # Demo page for UmdSync React integration
          end
        end
      RUBY
      
      File.write(controller_path, controller_content)
      puts "  ✓ Created app/controllers/umd_sync_demo_controller.rb"
    end
    
    # Create the demo view
    def create_demo_view!
      views_dir = File.join(Dir.pwd, 'app', 'views', 'umd_sync_demo')
      FileUtils.mkdir_p(views_dir)
      
      view_path = File.join(views_dir, 'react.html.erb')
      
      view_content = <<~ERB
        <% content_for :title, "UmdSync React Demo" %>
        
        <div class="container mx-auto px-4 py-8">
          <div class="max-w-2xl mx-auto text-center">
            <h1 class="text-4xl font-bold text-gray-900 mb-6">
              🎉 UmdSync React Demo
            </h1>
            
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-6 mb-8">
              <h2 class="text-xl font-semibold text-blue-900 mb-4">
                Your HelloWorld Component
              </h2>
              
              <!-- Render the React component using UmdSync helper -->
              <%= react_component('HelloWorld') %>
            </div>
            
            <div class="bg-gray-50 border border-gray-200 rounded-lg p-6 text-left">
              <h3 class="text-lg font-semibold text-gray-900 mb-3">
                How this works:
              </h3>
              <ul class="space-y-2 text-gray-700">
                <li>• React and React-DOM are loaded via UMD partials</li>
                <li>• Your components are bundled with webpack</li>
                <li>• The <code class="bg-gray-200 px-1 rounded">react_component</code> helper renders them</li>
                <li>• Everything integrates seamlessly with Rails 8</li>
              </ul>
              
              <div class="mt-4 p-3 bg-yellow-50 border-l-4 border-yellow-400">
                <p class="text-sm text-yellow-800">
                  <strong>Next steps:</strong> Edit <code>app/javascript/umd_sync/components/HelloWorld.jsx</code> 
                  and run <code>yarn build</code> to see your changes!
                </p>
              </div>
            </div>
            
            <div class="mt-8">
              <a href="/" class="inline-flex items-center px-4 py-2 bg-blue-600 border border-transparent rounded-md font-semibold text-xs text-white uppercase tracking-widest hover:bg-blue-700 focus:outline-none focus:border-blue-700 focus:ring focus:ring-blue-200 active:bg-blue-600 disabled:opacity-25 transition">
                ← Back to App
              </a>
            </div>
          </div>
        </div>
      ERB
      
      File.write(view_path, view_content)
      puts "  ✓ Created app/views/umd_sync_demo/react.html.erb"
    end
    
    # Add the demo route to routes.rb
    def add_demo_route!
      routes_file = File.join(Dir.pwd, 'config', 'routes.rb')
      
      unless File.exist?(routes_file)
        puts "  ⚠️  Routes file not found, skipping route addition"
        return
      end
      
      content = File.read(routes_file)
      
      # Find a good place to insert the route (before the final 'end')
      if content.match(/^(\s*)end\s*$/)
        indent = $1
        route_line = "#{indent}# UmdSync demo route (you can remove this)\n#{indent}get 'umd-sync/react', to: 'umd_sync_demo#react'\n\n"
        
        # Insert before the last 'end'
        updated_content = content.sub(/^(\s*)end\s*$/, "#{route_line}\\1end")
        File.write(routes_file, updated_content)
        puts "  ✓ Added route to config/routes.rb"
      else
        puts "  ⚠️  Could not automatically add route. Please add manually:"
        puts "     get 'umd-sync/react', to: 'umd_sync_demo#react'"
      end
    end
  end
end 