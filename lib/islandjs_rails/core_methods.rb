module IslandjsRails
  class Core
    # Additional core methods (part 2)
    
    def build_bundle!
      puts "🔨 Building IslandJS webpack bundle..."
      
      unless system('which yarn > /dev/null 2>&1')
        puts "❌ yarn not found, cannot build bundle"
        return false
      end
      
      unless system('yarn list webpack-cli > /dev/null 2>&1')
        puts "⚠️  webpack-cli not found, installing..."
        system('yarn add --dev webpack-cli@^5.1.4')
      end
      
      if ENV['NODE_ENV'] == 'production' || ENV['RAILS_ENV'] == 'production'
        success = system('yarn build')
      else
        success = system('yarn build > /dev/null 2>&1')
      end
      
      if success
        puts "✅ Bundle built successfully"
        return true
      else
        puts "❌ Build failed. Check your webpack configuration."
        return false
      end
    end

    def offer_demo_route!
      return if demo_route_exists?
      
      puts "\n🎨 Would you like to create a demo route to showcase your React island? (y/n)"
      response = STDIN.gets.chomp.downcase
      
      if response == 'y' || response == 'yes'
        create_demo_route!
        puts "\n🎉 Demo route created! Visit /islandjs/react to see your HelloWorld component in action."
      else
        puts "✓ Skipped demo route creation"
      end
    end

    def demo_route_exists?
      routes_file = File.join(Dir.pwd, 'config', 'routes.rb')
      return false unless File.exist?(routes_file)
      
      content = File.read(routes_file)
      content.include?('islandjs/react') || content.include?('islandjs_demo')
    end

    def create_demo_route!
      routes_file = File.join(Dir.pwd, 'config', 'routes.rb')
      
      unless File.exist?(routes_file)
        puts "  ⚠️  Routes file not found, skipping route addition"
        return
      end
      
      content = File.read(routes_file)
      
      if content.match(/^(\s*)end\s*$/)
        indent = $1
        route_line = "#{indent}# IslandJS demo route (you can remove this)\n#{indent}get 'islandjs/react', to: 'islandjs_demo#react'\n\n"
        
        updated_content = content.sub(/^(\s*)end\s*$/, "#{route_line}\\1end")
        File.write(routes_file, updated_content)
        puts "  ✓ Added route to config/routes.rb"
      else
        puts "  ⚠️  Could not automatically add route. Please add manually:"
        puts "     get 'islandjs/react', to: 'islandjs_demo#react'"
      end
    end

    def check_node_tools!
      unless system('which npm > /dev/null 2>&1')
        puts "❌ npm not found. Please install Node.js first."
        exit 1
      end
      
      unless system('which yarn > /dev/null 2>&1')
        puts "❌ yarn not found. Please install yarn first."
        exit 1
      end
      
      puts "✓ npm and yarn are available"
    end

    def ensure_package_json!
      if File.exist?(configuration.package_json_path)
        puts "✓ package.json already exists"
        return
      end
      
      package_json_content = {
        "name" => "islandjs-rails-app",
        "version" => "1.0.0",
        "description" => "Rails app with IslandJS React islands",
        "main" => "app/javascript/islandjs/index.js",
        "scripts" => {
          "build" => "webpack --mode=production",
          "watch" => "webpack --mode=development --watch"
        },
        "keywords" => ["rails", "react", "islands", "islandjs"],
        "author" => "",
        "license" => "MIT"
      }
      
      File.write(configuration.package_json_path, JSON.pretty_generate(package_json_content))
      puts "✓ Created package.json"
    end

    def install_essential_dependencies!
      puts "📦 Installing essential webpack dependencies..."
      puts "  Installing: #{ESSENTIAL_DEPENDENCIES.join(', ')}"
      
      missing_deps = ESSENTIAL_DEPENDENCIES.select do |dep|
        package_name = dep.split('@').first
        !package_installed?(package_name)
      end
      
      if missing_deps.empty?
        puts "✓ All essential dependencies already installed"
        return
      end
      
      success = system("yarn add --dev #{missing_deps.join(' ')}")
      
      unless success
        puts "❌ Failed to install essential dependencies"
        exit 1
      end
      
      puts "✓ Installed essential webpack dependencies"
    end

    def create_scaffolded_structure!
      puts "🏗️  Creating scaffolded structure..."
      
      js_dir = File.join(Dir.pwd, 'app', 'javascript', 'islandjs')
      FileUtils.mkdir_p(js_dir)
      
      index_js_path = File.join(js_dir, 'index.js')
      
      unless File.exist?(index_js_path)
        index_js_content = <<~JS
          // IslandJS Rails - Main entry point
          // This file is the webpack entry point for your JavaScript islands
          
          // Example React component imports (uncomment when you have components)
          // import HelloWorld from '../../components/HelloWorld.jsx';
          
          // Mount components to the global islandjsRails namespace
          // window.islandjsRails = {
          //   HelloWorld
          // };
          
          console.log('🏝️ IslandJS Rails loaded successfully!');
        JS
        
        File.write(index_js_path, index_js_content)
        puts "✓ Created app/javascript/islandjs/index.js"
      else
        puts "✓ app/javascript/islandjs/index.js already exists"
      end
      
      components_dir = File.join(Dir.pwd, 'components')
      FileUtils.mkdir_p(components_dir)
      
      gitkeep_path = File.join(components_dir, '.gitkeep')
      unless File.exist?(gitkeep_path)
        File.write(gitkeep_path, '')
        puts "✓ Created components/.gitkeep"
      else
        puts "✓ components/.gitkeep already exists"
      end
    end

    def inject_island_partials_into_layout!
      layout_path = File.join(Dir.pwd, 'app', 'views', 'layouts', 'application.html.erb')
      
      unless File.exist?(layout_path)
        puts "⚠️  Layout file not found: #{layout_path}"
        puts "   Please add manually to your layout:"
        puts "   <%= islands %>"
        return
      end
      
      content = File.read(layout_path)
      
      if content.include?('island_partials') && content.include?('island_bundle_script') || content.include?('islands')
        puts "✓ Island helper already present in layout"
        return
      end
      
      if match = content.match(/^(\s*)<\/head>/i)
        indent = match[1]
        island_injection = "#{indent}<!-- IslandJS: Auto-injected -->\n#{indent}<%= islands %>"
        
        updated_content = content.gsub(/^(\s*)<\/head>/i, "#{island_injection}\n\\1</head>")
        File.write(layout_path, updated_content)
        puts "✓ Auto-injected island helper into app/views/layouts/application.html.erb"
      else
        puts "⚠️  Could not find </head> tag in layout"
        puts "   Please add manually to your layout:"
        puts "   <%= islands %>"
      end
    end

    def ensure_node_modules_gitignored!
      gitignore_path = File.join(Dir.pwd, '.gitignore')
      
      unless File.exist?(gitignore_path)
        File.write(gitignore_path, "# IslandJS: Node.js dependencies\n/node_modules\n")
        puts "✓ Created .gitignore with node_modules"
        return
      end
      
      content = File.read(gitignore_path)
      
      node_modules_patterns = ['/node_modules', 'node_modules/', '**/node_modules/']
      already_ignored = node_modules_patterns.any? { |pattern| content.include?(pattern) }
      
      unless already_ignored
        File.write(gitignore_path, content + "\n# IslandJS: Node.js dependencies\n/node_modules\n")
        puts "✓ Added /node_modules to .gitignore"
      else
        puts "✓ .gitignore already configured for IslandJS"
      end
      
      island_patterns = ['!/public/islandjsRails*.js', '!/public/islandjsRails*.json']
      missing_patterns = island_patterns.reject { |pattern| content.include?(pattern) }
      
      unless missing_patterns.empty?
        additions = "\n# IslandJS: Track built assets\n" + missing_patterns.join("\n") + "\n"
        File.write(gitignore_path, content + additions)
        puts "✓ Added IslandJS asset tracking patterns to .gitignore"
      end
    end

    def install_package!(package_name, version = nil)
      island_url = find_working_island_url(package_name, version)
      
      unless island_url
        raise IslandNotFoundError, "No island build found for #{package_name}"
      end
      
      begin
        island_content = download_island_content(island_url)
      rescue => e
        raise IslandNotFoundError, "Failed to download island: #{e.message}"
      end
      
      global_name = detect_global_name(package_name, island_url)
      create_partial_file(package_name, island_content, global_name)
    end

    def download_island_content(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        response.body
      else
        raise IslandNotFoundError, "Failed to download from #{url}: #{response.code}"
      end
    end

    def create_partial_file(package_name, island_content, global_name = nil)
      partial_path = partial_path_for(package_name)
      
      FileUtils.mkdir_p(File.dirname(partial_path))
      
      partial_content = generate_partial_content(package_name, island_content, global_name)
      
      File.write(partial_path, partial_content)
      puts "  ✓ Created partial: #{File.basename(partial_path)}"
    end

    def generate_partial_content(package_name, island_content, global_name = nil)
      encoded_content = [island_content].pack('m0')
      
      <<~ERB
        <%# IslandJS partial for #{package_name} %>
        <%# Auto-generated - do not edit manually %>
        <script>
          (function() {
            // Decode and execute #{package_name} island
            var script = document.createElement('script');
            script.text = atob('<%= "#{encoded_content}" %>');
            document.head.appendChild(script);
            
            // Verify global is available
            if (typeof #{global_name || detect_global_name(package_name)} !== 'undefined') {
              console.log('🏝️ #{package_name} island loaded successfully');
            }
          })();
        </script>
      ERB
    end

    def package_json
      return @package_json if @package_json
      return nil unless File.exist?(configuration.package_json_path)
      
      begin
        @package_json = JSON.parse(File.read(configuration.package_json_path))
      rescue JSON::ParserError
        nil
      end
    end

    def installed_packages
      package_data = package_json
      return [] unless package_data
      
      dependencies = package_data.dig('dependencies') || {}
      dev_dependencies = package_data.dig('devDependencies') || {}
      
      (dependencies.keys + dev_dependencies.keys).uniq
    end

    def supported_package?(package_name)
      true
    end

    def partial_path_for(package_name)
      partial_name = package_name.gsub(/[@\/]/, '_').gsub(/-/, '_')
      File.join(configuration.partials_dir, "_#{partial_name}.html.erb")
    end

    def download_and_create_partial!(package_name)
      version = version_for(package_name)
      
      island_url = find_working_island_url(package_name, version)
      return unless island_url
      
      begin
        island_content = download_island_content(island_url)
        global_name = detect_global_name(package_name, island_url)
        create_partial_file(package_name, island_content, global_name)
      rescue => e
        puts "  ⚠️  Skipping #{package_name}: #{e.message}"
      end
    end

    def add_package_via_yarn(package_name, version = nil)
      package_spec = version ? "#{package_name}@#{version}" : package_name
      command = "yarn add #{package_spec}"
      
      stdout, stderr, status = Open3.capture3(command, chdir: defined?(Rails) ? Rails.root : Dir.pwd)
      
      unless status.success?
        raise YarnError, "Failed to add #{package_spec}: #{stderr}"
      end
      
      @package_json = nil
      puts "  ✓ Added to package.json: #{package_spec}"
    end

    def yarn_update!(package_name, version = nil)
      if version
        add_package_via_yarn(package_name, version)
      else
        command = "yarn upgrade #{package_name}"
        stdout, stderr, status = Open3.capture3(command, chdir: defined?(Rails) ? Rails.root : Dir.pwd)
        
        unless status.success?
          raise YarnError, "Failed to update #{package_name}: #{stderr}"
        end
        
        @package_json = nil
        puts "  ✓ Updated in package.json: #{package_name}"
      end
    end

    def remove_package_via_yarn(package_name)
      command = "yarn remove #{package_name}"
      
      stdout, stderr, status = Open3.capture3(command, chdir: defined?(Rails) ? Rails.root : Dir.pwd)
      
      unless status.success?
        raise YarnError, "Failed to remove #{package_name}: #{stderr}"
      end
      
      @package_json = nil
      puts "  ✓ Removed from package.json: #{package_name}"
    end

    def generate_webpack_config!
      webpack_content = <<~JS
        const path = require('path');
        const TerserPlugin = require('terser-webpack-plugin');
        const { WebpackManifestPlugin } = require('webpack-manifest-plugin');
        
        const isProduction = process.env.NODE_ENV === 'production';
        
        module.exports = {
          mode: isProduction ? 'production' : 'development',
          entry: {
            islandjsRailsBundle: ['./app/javascript/islandjs/index.js']
          },
          externals: {
            // IslandJS managed externals - do not edit manually
          },
          output: {
            filename: '[name].js',
            path: path.resolve(__dirname, 'public'),
            publicPath: '/',
            clean: false
          },
          module: {
            rules: [
              {
                test: /\\.(js|jsx)$/,
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
          optimization: {
            minimize: isProduction,
            minimizer: [new TerserPlugin()]
          },
          plugins: [
            new WebpackManifestPlugin({
              fileName: 'islandjsRailsManifest.json',
              publicPath: '/'
            })
          ],
          devtool: isProduction ? false : 'source-map'
        };
      JS
      
      File.write(configuration.webpack_config_path, webpack_content)
    end

    def url_accessible?(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      response.code == '200'
    rescue => e
      false
    end
    
    def has_partial?(package_name)
      File.exist?(partial_path_for(package_name))
    end
    
    def get_global_name_for_package(package_name)
      detect_global_name(package_name)
    end
    
    def reset_webpack_externals
      webpack_config_path = configuration.webpack_config_path
      return unless File.exist?(webpack_config_path)
      
      content = File.read(webpack_config_path)
      
      externals_block = <<~JS
      externals: {
        // IslandJS managed externals - do not edit manually
      },
      JS
      
      updated_content = content.gsub(
        /externals:\s*\{[^}]*\}(?:,)?/m,
        externals_block.chomp
      )
      
      File.write(webpack_config_path, updated_content)
      puts "  ✓ Reset webpack externals"
    end

    def update_webpack_externals(package_name = nil, global_name = nil)
      webpack_config_path = configuration.webpack_config_path
      return unless File.exist?(webpack_config_path)
      
      content = File.read(webpack_config_path)
      
      externals = {}
      installed_packages.each do |pkg|
        next unless supported_package?(pkg)
        externals[pkg] = get_global_name_for_package(pkg)
      end
      
      externals_lines = externals.map { |pkg, global| "    '#{pkg}': '#{global}'" }
      externals_block = <<~JS
      externals: {
        // IslandJS managed externals - do not edit manually
      #{externals_lines.join(",\n")}
      },
      JS
      
      updated_content = content.gsub(
        /externals:\s*\{[^}]*\}(?:,)?/m,
        externals_block.chomp
      )
      
      File.write(webpack_config_path, updated_content)
      puts "  ✓ Updated webpack externals"
    end
  end
end
