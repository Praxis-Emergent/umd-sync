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
      # Check if demo route already exists
      if demo_route_exists?
        puts "✓ Demo route already exists at /islandjs/react"
        return
      end
      
      print "\n❓ Would you like to create a demo route at /islandjs/react to showcase your HelloWorld component? (y/n): "
      answer = STDIN.gets.chomp.downcase
      
      if answer == 'y' || answer == 'yes'
        create_demo_route!
        puts "\n🎉 Demo route created! Visit http://localhost:3000/islandjs/react to see your React component in action."
        puts "💡 You can remove it later by deleting the route, controller, and view manually."
      else
        puts "\n💡 No problem! Here's how to render your HelloWorld component manually:"
        puts "   In any view: <%= react_component('HelloWorld') %>"
        puts "   Don't forget to: yarn build && rails server"
      end
    end

    def demo_route_exists?
      routes_file = File.join(Dir.pwd, 'config', 'routes.rb')
      return false unless File.exist?(routes_file)
      
      content = File.read(routes_file)
      content.include?('islandjs/react') || content.include?('islandjs_demo')
    end

    def create_demo_route!
      create_demo_controller!
      create_demo_view!
      add_demo_route!
    end

    def create_demo_controller!
      controller_dir = File.join(Dir.pwd, 'app', 'controllers')
      FileUtils.mkdir_p(controller_dir)
      
      controller_file = File.join(controller_dir, 'islandjs_demo_controller.rb')
      
      controller_content = <<~RUBY
        class IslandjsDemoController < ApplicationController
          def react
            # Demo route for showcasing IslandJS React integration
          end
        end
      RUBY
      
      File.write(controller_file, controller_content)
      puts "  ✓ Created islandjs_demo_controller"
    end

    def create_demo_view!
      view_dir = File.join(Dir.pwd, 'app', 'views', 'islandjs_demo')
      view_file = File.join(view_dir, 'react.html.erb')
      
      FileUtils.mkdir_p(view_dir)
      
      view_content = <<~ERB
        <div class="max-w-4xl mx-auto p-8">
          <h1 class="text-3xl font-bold mb-6">🏝️ IslandJS Rails Demo</h1>
          <div class="bg-gray-50 rounded-lg p-6 mb-6">
            <h2 class="text-xl font-semibold mb-4">React Component Island</h2>
            <p class="text-gray-600 mb-4">This demonstrates a React component rendered as an "island" within a Rails application.</p>
            <!-- React Component Island -->
            <div id="hello-world-demo" class="border-2 border-dashed border-blue-300 rounded-lg p-4 bg-white">
              <%= react_component('HelloWorld', { message: 'Hello from IslandJS!' }) %>
            </div>
          </div>
          <div class="prose">
            <h3>How it works:</h3>
            <ol>
              <li>Rails renders this ERB template</li>
              <li>The `react_component` helper injects the React component</li>
              <li>IslandJS loads React from CDN and renders the component</li>
              <li>The component runs independently as a JavaScript "island"</li>
            </ol>
            <p><a href="/" class="text-blue-600 hover:text-blue-800">← Back to Home</a></p>
          </div>
        </div>
      ERB
      
      File.write(view_file, view_content)
      puts "  ✓ Created demo view at app/views/islandjs_demo/react.html.erb"
    end

    def add_demo_route!
      routes_file = File.join(Dir.pwd, 'config', 'routes.rb')
      
      unless File.exist?(routes_file)
        puts "  ⚠️  Routes file not found, skipping route addition"
        return
      end
      
      content = File.read(routes_file)
      
      # Find a good place to insert the route (before the final 'end')
      if match = content.match(/^(\s*)end\s*$/)
        indent = match[1] # Capture the existing indentation
        route_lines = "#{indent}# IslandJS demo route (you can remove this)\n#{indent}get 'islandjs/react', to: 'islandjs_demo#react'\n"
        
        # Insert before the last 'end' with proper indentation
        updated_content = content.sub(/^(\s*)end\s*$/, "#{route_lines}\n\\1end")
        File.write(routes_file, updated_content)
        puts "  ✓ Added route to config/routes.rb"
      else
        puts "  ⚠️  Could not automatically add route. Please add manually:"
        puts "     get 'islandjs/react', to: 'islandjs_demo#react'"
      end
    end

    def check_node_tools!
      unless system('which npm > /dev/null 2>&1')
        puts "❌ npm not found. Please install Node.js and npm first."
        exit 1
      end
      
      unless system('which yarn > /dev/null 2>&1')
        puts "❌ yarn not found. Please install yarn first: npm install -g yarn"
        exit 1
      end
      
      puts "✓ npm and yarn are available"
    end

    def ensure_package_json!
      if File.exist?(configuration.package_json_path)
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
      
      File.write(configuration.package_json_path, JSON.pretty_generate(basic_package_json))
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
        puts "❌ Failed to install dependencies"
        exit 1
      end
      
      puts "✓ Installed essential webpack dependencies"
    end

    def create_scaffolded_structure!
      puts "🏗️  Creating scaffolded structure..."
      
      js_dir = File.join(Dir.pwd, 'app', 'javascript', 'islands')
      
      FileUtils.mkdir_p(js_dir)
      
      index_js_path = File.join(js_dir, 'index.js')
      
      unless File.exist?(index_js_path)
        # Copy from gem's template file instead of hardcoded string
        gem_template_path = File.join(__dir__, '..', '..', 'app', 'javascript', 'islands', 'index.js')
        
        if File.exist?(gem_template_path)
          FileUtils.cp(gem_template_path, index_js_path)
          puts "✓ Created app/javascript/islands/index.js"
        else
          puts "⚠️  Template file not found: #{gem_template_path}"
        end
      else
        puts "✓ app/javascript/islands/index.js already exists"
      end
      
      components_dir = File.join(Dir.pwd, 'app', 'javascript', 'islands', 'components')
      FileUtils.mkdir_p(components_dir)
      
      gitkeep_path = File.join(components_dir, '.gitkeep')
      unless File.exist?(gitkeep_path)
        File.write(gitkeep_path, '')
        puts "✓ Created components/.gitkeep"
      else
        puts "✓ components/.gitkeep already exists"
      end
      
      FileUtils.mkdir_p(configuration.partials_dir)
      puts "✓ Created #{configuration.partials_dir}"
    end

    # Automatically inject islands helper into Rails layout
    def inject_umd_partials_into_layout!
      layout_path = File.join(Dir.pwd, 'app', 'views', 'layouts', 'application.html.erb')
      
      unless File.exist?(layout_path)
        puts "⚠️  Layout file not found: #{layout_path}"
        puts "   Please add manually to your layout:"
        puts "   <%= islands %>"
        return
      end
      
      content = File.read(layout_path)
      
      # Check if already injected (idempotent)
      if content.include?('island_partials') && content.include?('island_bundle_script') || content.include?('islands')
        puts "✓ Islands helper already present in layout"
        return
      end
      
      # Find the closing </head> tag and inject before it with proper indentation
      if match = content.match(/^(\s*)<\/head>/i)
        indent = match[1] # Capture the existing indentation
        islands_injection = "#{indent}<!-- IslandjsRails: Auto-injected -->\n#{indent}<%= islands %>"
        
        # Inject before </head> with proper indentation
        updated_content = content.gsub(/^(\s*)<\/head>/i, "#{islands_injection}\n\\1</head>")
        File.write(layout_path, updated_content)
        puts "✓ Auto-injected UMD helper into app/views/layouts/application.html.erb"
      else
        puts "⚠️  Could not find </head> tag in layout"
        puts "   Please add manually to your layout:"
        puts "   <%= islands %>"
      end
    end

    # Ensure node_modules is in .gitignore and IslandJS assets are tracked
    def ensure_node_modules_gitignored!
      gitignore_path = File.join(Dir.pwd, '.gitignore')
      
      unless File.exist?(gitignore_path)
        puts "⚠️  .gitignore not found, creating one..."
        gitignore_content = <<~GITIGNORE
          /node_modules
          
          # IslandJS: Track webpack bundles for deployment
          !/public/islands_manifest.json
          !/public/islands_bundle.js
        GITIGNORE
        File.write(gitignore_path, gitignore_content)
        puts "✓ Created .gitignore with /node_modules and IslandJS asset tracking"
        return
      end
      
      content = File.read(gitignore_path)
      updated = false
      
      # Check if node_modules is already ignored (various patterns)
      unless content.match?(/^\/node_modules\s*$/m) || 
             content.match?(/^node_modules\/?\s*$/m) ||
             content.match?(/^\*\*\/node_modules\/?\s*$/m)
        content += "\n# IslandJS: Node.js dependencies\n/node_modules\n"
        updated = true
        puts "✓ Added /node_modules to .gitignore"
      end
      
      # Check if IslandJS assets are already tracked
      unless content.include?('!/public/islands_manifest.json') && content.include?('!/public/islands_bundle.js')
        content += "\n# IslandJS: Track webpack bundles for deployment\n!/public/islands_manifest.json\n!/public/islands_bundle.js\n"
        updated = true
        puts "✓ Added IslandJS asset tracking to .gitignore"
      end
      
      if updated
        File.write(gitignore_path, content)
      else
        puts "✓ .gitignore already configured for IslandjsRails"
      end
    end

    def install_package!(package_name, version = nil)
      # Get version from package.json
      actual_version = version_for(package_name)
      
      unless actual_version
        raise IslandjsRails::PackageNotFoundError, "#{package_name} not found in package.json"
      end
      
      # Try to find working UMD URL
      umd_url, global_name = find_working_umd_url(package_name, actual_version)
      
      unless umd_url
        raise IslandjsRails::UmdNotFoundError, "No UMD build found for #{package_name}@#{actual_version}. This package may not provide a UMD build."
      end
      
      # Download UMD content
      umd_content = download_umd_content(umd_url)
      
      # Create partial
      create_partial_file(package_name, umd_content, global_name)
    end

    def download_umd_content(url)
      uri = URI(url)
      response = Net::HTTP.get_response(uri)
      
      if response.code == '200'
        response.body
      else
        raise IslandjsRails::Error, "Failed to download UMD from #{url}: #{response.code}"
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
      safe_name = package_name.gsub(/[@\/]/, '_').gsub(/-/, '_')
      global_name ||= detect_global_name(package_name)
      
      # Base64 encode the content to completely avoid ERB parsing issues
      require 'base64'
      encoded_content = Base64.strict_encode64(island_content)
      
      <<~ERB
        <%# #{global_name} UMD Library %>
        <%# Global: #{global_name} %>
        <%# Generated by IslandjsRails %>
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
      configuration.partials_dir.join("_#{partial_name}.html.erb")
    end

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
            islands_bundle: ['./app/javascript/islands/index.js']
          },
          externals: {
            // IslandjsRails managed externals - do not edit manually
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
              fileName: 'islands_manifest.json',
              publicPath: '/'
            })
          ],
          devtool: isProduction ? false : 'eval-source-map'
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
        // IslandjsRails managed externals - do not edit manually
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
        next unless has_partial?(pkg)
        externals[pkg] = get_global_name_for_package(pkg)
      end
      
      externals_lines = externals.map { |pkg, global| "    \"#{pkg}\": \"#{global}\"" }
      externals_block = <<~JS
      externals: {
        // IslandjsRails managed externals - do not edit manually
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
