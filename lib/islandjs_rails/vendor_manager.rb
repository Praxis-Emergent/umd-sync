require 'json'
require 'digest'
require 'fileutils'

module IslandjsRails
  class VendorManager
    attr_reader :configuration

    def initialize(configuration)
      @configuration = configuration
    end

    # Install a package to vendor directory
    def install_package!(package_name, version = nil)
      puts "📦 Installing #{package_name} to vendor directory..."
      
      # Download UMD content
      content, actual_version = download_umd_content(package_name, version)
      return false unless content

      # Ensure vendor directory exists
      FileUtils.mkdir_p(configuration.vendor_dir)

      # Save to vendor file
      vendor_file = configuration.vendor_file_path(package_name, actual_version)
      File.write(vendor_file, content)

      # Update manifest
      update_manifest!(package_name, actual_version, File.basename(vendor_file))

      # Regenerate vendor partial
      regenerate_vendor_partial!

      puts "✅ #{package_name}@#{actual_version} installed to vendor"
      true
    end

    # Remove a package from vendor directory
    def remove_package!(package_name)
      puts "🗑️  Removing #{package_name} from vendor..."
      
      manifest = read_manifest
      lib_entry = manifest['libs'].find { |lib| lib['name'] == package_name }
      
      return false unless lib_entry

      # Remove file
      vendor_file = configuration.vendor_dir.join(lib_entry['file'])
      File.delete(vendor_file) if File.exist?(vendor_file)

      # Update manifest
      manifest['libs'].reject! { |lib| lib['name'] == package_name }
      write_manifest(manifest)

      # Regenerate vendor partial
      regenerate_vendor_partial!

      puts "✅ #{package_name} removed from vendor"
      true
    end

    # Rebuild combined bundle (for :external_combined mode)
    def rebuild_combined_bundle!
      return unless configuration.vendor_script_mode == :external_combined

      puts "🔨 Building combined vendor bundle..."
      
      manifest = read_manifest
      return if manifest['libs'].empty?

      # Order libraries according to vendor_order
      ordered_libs = order_libraries(manifest['libs'])
      
      # Combine all UMD content
      combined_content = build_combined_content(ordered_libs)
      
      # Generate hash for cache busting
      content_hash = Digest::SHA256.hexdigest(combined_content)[0, 12]
      
      # Write combined file
      combined_file = configuration.combined_vendor_path(content_hash)
      File.write(combined_file, combined_content)
      
      # Update manifest with combined info
      manifest['combined'] = {
        'hash' => content_hash,
        'file' => File.basename(combined_file),
        'size_kb' => (combined_content.bytesize / 1024.0).round(1)
      }
      write_manifest(manifest)

      # Warn if bundle is too large
      size_mb = combined_content.bytesize / (1024.0 * 1024.0)
      if size_mb > 1.0
        puts "⚠️  Warning: Combined bundle is #{size_mb.round(1)}MB - consider splitting libraries"
      end

      # Clean up old combined files
      cleanup_old_combined_files!

      # Regenerate vendor partial
      regenerate_vendor_partial!

      puts "✅ Combined bundle built: #{content_hash}"
      true
    end

    private

    def download_umd_content(package_name, version = nil)
      # Use existing UMD download logic from core
      core = IslandjsRails.core
      
      # Try to find working UMD URL
      version ||= core.version_for(package_name) || 'latest'
      url = core.find_working_island_url(package_name, version)
      
      return [nil, nil] unless url

      content = core.download_umd_content(url)
      return [nil, nil] unless content

      # Extract actual version from URL if needed
      actual_version = extract_version_from_url(url) || version
      
      [content, actual_version]
    end

    def extract_version_from_url(url)
      # Extract version from CDN URLs like unpkg.com/react@18.2.0/...
      match = url.match(/@([^\/]+)\//)
      match ? match[1] : nil
    end

    def read_manifest
      manifest_path = configuration.vendor_manifest_path
      
      if File.exist?(manifest_path)
        JSON.parse(File.read(manifest_path))
      else
        { 'libs' => [] }
      end
    end

    def write_manifest(manifest)
      FileUtils.mkdir_p(File.dirname(configuration.vendor_manifest_path))
      File.write(configuration.vendor_manifest_path, JSON.pretty_generate(manifest))
    end

    def update_manifest!(package_name, version, filename)
      manifest = read_manifest
      
      # Remove existing entry for this package
      manifest['libs'].reject! { |lib| lib['name'] == package_name }
      
      # Add new entry
      manifest['libs'] << {
        'name' => package_name,
        'version' => version,
        'file' => filename
      }
      
      write_manifest(manifest)
    end

    def order_libraries(libs)
      # Sort according to vendor_order, then alphabetically
      ordered = []
      remaining = libs.dup
      
      # Add libraries in vendor_order first
      configuration.vendor_order.each do |name|
        lib = remaining.find { |l| l['name'] == name }
        if lib
          ordered << lib
          remaining.delete(lib)
        end
      end
      
      # Add remaining libraries alphabetically
      ordered + remaining.sort_by { |lib| lib['name'] }
    end

    def build_combined_content(ordered_libs)
      content_parts = []
      
      ordered_libs.each do |lib|
        vendor_file = configuration.vendor_dir.join(lib['file'])
        next unless File.exist?(vendor_file)
        
        # Add header comment
        content_parts << "// #{lib['name']}@#{lib['version']}"
        
        # Add library content
        content_parts << File.read(vendor_file)
        
        # Add separator
        content_parts << ""
      end
      
      content_parts.join("\n")
    end

    def cleanup_old_combined_files!
      # Keep only the 2 most recent combined files
      pattern = configuration.vendor_dir.join("#{configuration.combined_basename}-*.js")
      combined_files = Dir.glob(pattern).sort_by { |f| File.mtime(f) }.reverse
      
      # Delete all but the 2 most recent
      combined_files[2..-1]&.each do |file|
        File.delete(file)
        puts "  🗑️  Cleaned up old combined file: #{File.basename(file)}"
      end
    end

    def regenerate_vendor_partial!
      case configuration.vendor_script_mode
      when :external_split
        generate_split_partial!
      when :external_combined
        generate_combined_partial!
      else
        raise "Unknown vendor_script_mode: #{configuration.vendor_script_mode}"
      end
    end

    def generate_split_partial!
      manifest = read_manifest
      
      content = <<~ERB
        <%# IslandJS Rails Vendor UMD Scripts (Split Mode) %>
        <%# Generated automatically - do not edit manually %>
        <% # Load each library separately for better caching %>
      ERB
      
      manifest['libs'].each do |lib|
        content += <<~ERB
          <script src="/islands/vendor/#{lib['file']}" data-turbo-track="reload"></script>
        ERB
      end
      
      write_vendor_partial(content)
    end

    def generate_combined_partial!
      manifest = read_manifest
      combined_info = manifest['combined']
      
      return generate_split_partial! unless combined_info
      
      content = <<~ERB
        <%# IslandJS Rails Vendor UMD Scripts (Combined Mode) %>
        <%# Generated automatically - do not edit manually %>
        <%# Combined bundle: #{combined_info['size_kb']}KB %>
        <script src="/islands/vendor/#{combined_info['file']}" data-turbo-track="reload"></script>
      ERB
      
      write_vendor_partial(content)
    end

    def write_vendor_partial(content)
      FileUtils.mkdir_p(File.dirname(configuration.vendor_partial_path))
      File.write(configuration.vendor_partial_path, content)
      puts "  ✓ Generated vendor partial: #{configuration.vendor_partial_path}"
    end
  end
end
