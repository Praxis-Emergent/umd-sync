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
      content.include?('islandjs_demo') || content.include?('islandjs/react') || content.include?("get 'islandjs'")
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
      copy_template_file('app/controllers/islandjs_demo_controller.rb', controller_file)
    end

    def create_demo_view!
      view_dir = File.join(Dir.pwd, 'app', 'views', 'islandjs_demo')
      FileUtils.mkdir_p(view_dir)
      
      # Copy demo view templates from gem
      copy_demo_template('index.html.erb', view_dir)
      copy_demo_template('react.html.erb', view_dir)
    end

    def copy_demo_template(template_name, destination_dir)
      gem_root = File.expand_path('../../..', __FILE__)
      template_path = File.join(gem_root, 'lib', 'templates', 'app', 'views', 'islandjs_demo', template_name)
      destination_path = File.join(destination_dir, template_name)
      
      if File.exist?(template_path)
        FileUtils.cp(template_path, destination_path)
        puts "  ✓ Created #{template_name} at app/views/islandjs_demo/#{template_name}"
      else
        puts "  ⚠️  Template not found: #{template_path}"
      end
    end
    
    def copy_template_file(template_name, destination_path)
      gem_root = File.expand_path('../../..', __FILE__)
      template_path = File.join(gem_root, 'lib', 'templates', template_name)
      
      if File.exist?(template_path)
        FileUtils.cp(template_path, destination_path)
        puts "  ✓ Created #{File.basename(template_name)} from template"
      else
        puts "  ⚠️  Template not found: #{template_path}"
      end
    end
    
    def get_demo_routes_content(indent, has_root_route)
      gem_root = File.expand_path('../../..', __FILE__)
      template_path = File.join(gem_root, 'lib', 'templates', 'config', 'demo_routes.rb')
      
      if File.exist?(template_path)
        routes_content = File.read(template_path)
        # Apply indentation to each line
        route_lines = routes_content.lines.map { |line| "#{indent}#{line}" }.join
        
        # Add root route if none exists
        unless has_root_route
          root_route = "#{indent}root 'islandjs_demo#index'\n"
          route_lines = root_route + route_lines
        end
        
        route_lines
      else
        # Fallback to hardcoded routes if template not found
        route_lines = "#{indent}# IslandJS demo routes (you can remove these)\n"
        unless has_root_route
          route_lines += "#{indent}root 'islandjs_demo#index'\n"
        end
        route_lines += "#{indent}get 'islandjs', to: 'islandjs_demo#index'\n"
        route_lines += "#{indent}get 'islandjs/react', to: 'islandjs_demo#react'\n"
        route_lines
      end
    end

    def add_demo_route!
      routes_file = File.join(Dir.pwd, 'config', 'routes.rb')
      return unless File.exist?(routes_file)
      
      content = File.read(routes_file)
      
      # Check if root route already exists
      has_root_route = content.include?('root ') || content.match(/^\s*root\s/)
      
      # Find the Rails.application.routes.draw block
      if content.match(/Rails\.application\.routes\.draw do\s*$/)
        # Determine indentation
        indent = content.match(/^(\s*)Rails\.application\.routes\.draw do\s*$/)[1]
        
        # Build route lines from template
        route_lines = get_demo_routes_content(indent, has_root_route)
        
        # Add the routes after the draw line
        updated_content = content.sub(
          /(Rails\.application\.routes\.draw do\s*$)/,
          "\\1\n#{route_lines}"
        )
        
        File.write(routes_file, updated_content)
        puts "  ✓ Added demo routes to config/routes.rb:"
        unless has_root_route
          puts "     root 'islandjs_demo#index' (set as homepage)"
        end
        puts "     get 'islandjs', to: 'islandjs_demo#index'"
        puts "     get 'islandjs/react', to: 'islandjs_demo#react'"
      end
    end

    def setup_vendor_system!
      # Initialize empty vendor manifest
      manifest_path = configuration.vendor_manifest_path
      unless File.exist?(manifest_path)
        require 'json'
        initial_manifest = { 'libs' => [] }
        FileUtils.mkdir_p(File.dirname(manifest_path))
        File.write(manifest_path, JSON.pretty_generate(initial_manifest))
        puts "  ✓ Created vendor manifest"
      end

      # Generate initial empty vendor partial
      vendor_manager = IslandjsRails.vendor_manager
      vendor_manager.send(:regenerate_vendor_partial!)
      puts "  ✓ Generated vendor UMD partial"
    end

    def inject_islands_helper_into_layout!
      layout_path = find_application_layout
      return unless layout_path

      content = File.read(layout_path)
      islands_helper_line = '<%= islands %>'
      vendor_render_line = '<%= render "shared/islands/vendor_umd" %>'

      # Check if islands helper or vendor partial is already included
      if content.include?(islands_helper_line) || content.include?('islands %>') ||
         content.include?(vendor_render_line) || content.include?('render "shared/islands/vendor_umd"')
        puts "  ✓ Islands helper already included in layout"
        return
      end

      # Try to inject after existing head content or before </head>
      if content.include?('</head>')
        updated_content = content.sub(
          /\s*<\/head>/,
          "\n    #{islands_helper_line}\n  </head>"
        )
        
        File.write(layout_path, updated_content)
        puts "  ✓ Added islands helper to #{File.basename(layout_path)}"
      else
        puts "  ⚠️  Could not automatically inject islands helper. Please add manually:"
        puts "     #{islands_helper_line}"
      end
    end

    def find_application_layout
      # Look for application layout in common locations
      layout_paths = [
        File.join(Dir.pwd, 'app', 'views', 'layouts', 'application.html.erb'),
        File.join(Dir.pwd, 'app', 'views', 'layouts', 'application.html.haml'),
        File.join(Dir.pwd, 'app', 'views', 'layouts', 'application.html.slim')
      ]
      
      layout_paths.find { |path| File.exist?(path) }
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
      
      # Use template and customize with current directory name
      template_path = File.join(__dir__, '..', 'templates', 'package.json')
      template_content = File.read(template_path)
      package_json = JSON.parse(template_content)
      
      # Customize with current directory name
      package_json["name"] = File.basename(Dir.pwd)
      
      File.write(configuration.package_json_path, JSON.pretty_generate(package_json))
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
      
      # Copy entire JavaScript islands structure from templates
      gem_root = File.expand_path('../../..', __FILE__)
      template_js_dir = File.join(gem_root, 'lib', 'templates', 'app', 'javascript', 'islands')
      target_js_dir = File.join(Dir.pwd, 'app', 'javascript', 'islands')
      
      if Dir.exist?(template_js_dir)
        FileUtils.mkdir_p(File.dirname(target_js_dir))
        FileUtils.cp_r(template_js_dir, File.dirname(target_js_dir))
        puts "✓ Created JavaScript islands structure from templates"
      else
        puts "⚠️  Template JavaScript directory not found: #{template_js_dir}"
        # Fallback: create minimal structure
        FileUtils.mkdir_p(File.join(target_js_dir, 'components'))
        File.write(File.join(target_js_dir, 'components', '.gitkeep'), '')
        puts "✓ Created minimal JavaScript structure"
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

    # Ensure node_modules is in .gitignore
    def ensure_node_modules_gitignored!
      gitignore_path = File.join(Dir.pwd, '.gitignore')
      
      unless File.exist?(gitignore_path)
        puts "⚠️  .gitignore not found, creating one..."
        gitignore_content = <<~GITIGNORE
          /node_modules
        GITIGNORE
        File.write(gitignore_path, gitignore_content)
        puts "✓ Created .gitignore with /node_modules"
        return
      end
      
      content = File.read(gitignore_path)
      
      # Check if node_modules is already ignored (various patterns)
      unless content.match?(/^\/node_modules\s*$/m) || 
             content.match?(/^node_modules\/?\s*$/m) ||
             content.match?(/^\*\*\/node_modules\/?\s*$/m)
        content += "\n# IslandJS: Node.js dependencies\n/node_modules\n"
        File.write(gitignore_path, content)
        puts "✓ Added /node_modules to .gitignore"
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
        # Force UTF-8 encoding to avoid encoding errors when writing to file
        response.body.force_encoding('UTF-8')
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
      copy_template_file('webpack.config.js', configuration.webpack_config_path)
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
      
      # Get installed packages from vendor manifest instead of partials
      vendor_manager = IslandjsRails.vendor_manager
      manifest = vendor_manager.send(:read_manifest)
      
      manifest['libs'].each do |lib|
        pkg = lib['name']
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
