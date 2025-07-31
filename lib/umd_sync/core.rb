module UmdSync
  class Core
    attr_reader :configuration

    def initialize
      @configuration = UmdSync.configuration
    end

    # Initialize UmdSync in a Rails project
    def init!
      puts "🚀 Initializing UmdSync..."
      
      # Create directories
      FileUtils.mkdir_p(configuration.partials_dir)
      puts "✓ Created #{configuration.partials_dir}"
      
      # Generate webpack config if it doesn't exist
      unless File.exist?(configuration.webpack_config_path)
        generate_webpack_config!
        puts "✓ Generated webpack.config.js"
      end
      
      puts "✅ UmdSync initialized successfully!"
      puts "💡 Try: umd-sync install react"
    end

    # Install a new UMD package
    def install!(package_name, version = nil)
      puts "📦 Installing UMD package: #{package_name}"
      
      # Add to package.json via yarn if not present
      add_package_via_yarn(package_name, version) unless package_installed?(package_name)
      
      # Install the UMD
      install_package!(package_name, version)
      
      puts "✅ Successfully installed #{package_name}!"
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
            bundle: ['./jsx/index.js']
          },
          externals: {
            // UmdSync managed externals - do not edit manually
            // These will be auto-updated by umd-sync
          },
          output: {
            path: path.resolve(__dirname, 'public/assets'),
            filename: '[name].[contenthash].js',
            library: {
              name: 'umd_sync_react',
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
  end
end 