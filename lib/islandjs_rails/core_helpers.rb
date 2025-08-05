module IslandjsRails
  class Core
    # Additional helper methods for core functionality
    
    def update_webpack_externals(package_name = nil, global_name = nil)
      webpack_config_path = configuration.webpack_config_path
      return unless File.exist?(webpack_config_path)
      
      content = File.read(webpack_config_path)
      
      # Get all installed packages from vendor manifest
      externals = {}
      vendor_manager = IslandjsRails.vendor_manager
      manifest = vendor_manager.send(:read_manifest)
      
      manifest['libs'].each do |lib|
        pkg = lib['name']
        externals[pkg] = get_global_name_for_package(pkg)
      end
      
      # Generate externals block
      externals_lines = externals.map { |pkg, global| "    \"#{pkg}\": \"#{global}\"" }
      externals_block = <<~JS
      externals: {
        // IslandjsRails managed externals - do not edit manually
      #{externals_lines.join(",\n")}
      },
      JS
      
      # Replace existing externals block
      updated_content = content.gsub(
        /externals:\s*\{[^}]*\}(?:,)?/m,
        externals_block.chomp
      )
      
      File.write(webpack_config_path, updated_content)
      puts "  ✓ Updated webpack externals"
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
      
      # Find a good place to insert the route (before the final 'end')
      if content.match(/^(\s*)end\s*$/)
        indent = $1
        route_line = "#{indent}# IslandJS demo route (you can remove this)\n#{indent}get 'islandjs/react', to: 'islandjs_demo#react'\n\n"
        
        # Insert before the last 'end'
        updated_content = content.sub(/^(\s*)end\s*$/, "#{route_line}\\1end")
        File.write(routes_file, updated_content)
        puts "  ✓ Added route to config/routes.rb"
      else
        puts "  ⚠️  Could not automatically add route. Please add manually:"
        puts "     get 'islandjs/react', to: 'islandjs_demo#react'"
      end
    end
  end
end
