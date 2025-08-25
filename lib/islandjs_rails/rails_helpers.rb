module IslandjsRails
  module RailsHelpers
    # Main helper method that combines all IslandJS functionality
    def islands
      output = []
      output << island_partials  # Now uses vendor UMD partial
      output << island_bundle_script
      output << umd_versions_debug if umd_debug_enabled?
      output.compact.join("\n").html_safe
    end

    # Render all island partials (CDN scripts for external libraries)
    # Now delegates to the vendor UMD partial for better performance
    def island_partials
      render(partial: "shared/islands/vendor_umd").html_safe
    rescue ActionView::MissingTemplate
      if Rails.env.development?
        "<!-- IslandJS: Vendor UMD partial missing. Run: rails islandjs:init -->".html_safe
      else
        "".html_safe
      end
    end

    # Render the main IslandJS bundle script tag
    def island_bundle_script
      # Use configured manifest_path only
      manifest_path = IslandjsRails.configuration.manifest_path

      bundle_path = '/islands_bundle.js'
      
      unless File.exist?(manifest_path)
        # Fallback to direct bundle path when no manifest
        return html_safe_string("<script src=\"#{bundle_path}\" defer></script>")
      end
      
      begin
        manifest = JSON.parse(File.read(manifest_path))
        # Look for islands_bundle.js in manifest
        bundle_file = manifest['islands_bundle.js']
        
        if bundle_file
          html_safe_string("<script src=\"#{bundle_file}\" defer></script>")
        else
          # Fallback to direct bundle path
          html_safe_string("<script src=\"#{bundle_path}\" defer></script>")
        end
      rescue JSON::ParserError
        # Fallback to direct bundle path on manifest parse error
        html_safe_string("<script src=\"#{bundle_path}\" defer></script>")
      end
    end

    # Mount a React component with props and Turbo-compatible lifecycle
    # Supports optional placeholder content via block or options
    def react_component(component_name, props = {}, options = {}, &block)
      # Generate component ID - use custom container_id if provided
      if options[:container_id]
        component_id = options[:container_id]
      else
        component_id = "react-#{component_name.gsub(/([A-Z])/, '-\1').downcase.gsub(/^-/, '')}-#{SecureRandom.hex(4)}"
      end
      
      # Extract options
      tag_name = options[:tag] || 'div'
      css_class = options[:class] || ''
      namespace = options[:namespace] || 'window.islandjsRails'
      
      # Handle placeholder options
      placeholder_class = options[:placeholder_class]
      placeholder_style = options[:placeholder_style]
      
      # For turbo-cache compatibility, store initial state as JSON in data attribute
      initial_state_json = props.to_json
      
      # Generate data attributes from props with proper HTML escaping (keeping for backward compatibility)
      data_attrs = props.map do |key, value|
        # Convert both camelCase and snake_case to kebab-case
        attr_name = key.to_s.gsub(/([A-Z])/, '-\1').gsub('_', '-').downcase.gsub(/^-/, '')
        # Properly escape HTML entities
        attr_value = if value.nil?
          ''
        else
          value.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
        end
        "data-#{attr_name}=\"#{attr_value}\""
      end.join(' ')
      
      # Generate optional chaining syntax for custom namespaces
      namespace_with_optional = if namespace != 'window.islandjsRails' && !namespace.include?('?')
        namespace + '?'
      else
        namespace
      end
      
      # Generate the mounting script - pass container_id as the only prop for turbo-cache pattern
      mount_script = generate_react_mount_script(component_name, component_id, namespace, namespace_with_optional)
      
      # Return the container div with data-initial-state and script
      data_part = data_attrs.empty? ? '' : " #{data_attrs}"
      class_part = css_class.empty? ? '' : " class=\"#{css_class}\""
      
      # Add data-initial-state for turbo-cache compatibility
      initial_state_attr = " data-initial-state=\"#{initial_state_json.gsub('"', '&quot;')}\""
      
      # Generate placeholder content
      placeholder_content = if block_given?
        placeholder_html = capture(&block)
        "<div data-island-placeholder=\"true\">#{placeholder_html}</div>"
      elsif placeholder_class || placeholder_style
        class_attr = placeholder_class ? " class=\"#{placeholder_class}\"" : ""
        style_attr = placeholder_style ? " style=\"#{placeholder_style}\"" : ""
        "<div data-island-placeholder=\"true\"#{class_attr}#{style_attr}></div>"
      else
        ""
      end
      
      # Build container HTML with optional placeholder
      if placeholder_content.empty?
        container_html = "<#{tag_name} id=\"#{component_id}\"#{class_part}#{data_part}#{initial_state_attr}></#{tag_name}>"
      else
        container_html = "<#{tag_name} id=\"#{component_id}\"#{class_part}#{data_part}#{initial_state_attr}>#{placeholder_content}</#{tag_name}>"
      end
      
      html_safe_string("#{container_html}\n#{mount_script}")
    end

    # Mount a Vue component with props and Turbo-compatible lifecycle  
    def vue_component(component_name, props = {}, options = {})
      # Generate unique ID for this component instance
      component_id = "vue-#{component_name.downcase}-#{SecureRandom.hex(4)}"
      
      # Prepare props as JSON
      props_json = props.to_json
      
      # Extract options
      tag_name = options[:tag] || 'div'
      css_class = options[:class] || ''
      
      # Generate the mounting script
      mount_script = generate_vue_mount_script(component_name, component_id, props_json)
      
      # Return the container div and script
      container_html = "<#{tag_name} id=\"#{component_id}\" class=\"#{css_class}\"></#{tag_name}>"
      
      html_safe_string("#{container_html}\n#{mount_script}")
    end

    # Generic island component helper
    def island_component(framework, component_name, props = {}, options = {})
      case framework.to_s.downcase
      when 'react'
        react_component(component_name, props, options)
      when 'vue'
        vue_component(component_name, props, options)
      else
        html_safe_string("<!-- Unsupported framework: #{framework} -->")
      end
    end

    # Debug helper to show available components
    def island_debug
      return '' unless Rails.env.development?
      
      debug_info = {
        bundle_path: find_bundle_path,
        partials_count: Dir.glob(File.join(IslandjsRails.configuration.partials_dir, '*.html.erb')).count,
        webpack_config_exists: File.exist?(IslandjsRails.configuration.webpack_config_path),
        package_json_exists: File.exist?(IslandjsRails.configuration.package_json_path)
      }
      
      debug_html = <<~HTML
        <div style="background: #f0f0f0; padding: 10px; margin: 10px 0; border: 1px solid #ccc; font-family: monospace; font-size: 12px;">
          <strong>🏝️ IslandJS Debug Info:</strong><br>
          Bundle Path: #{debug_info[:bundle_path] || 'Not found'}<br>
          Partials: #{debug_info[:partials_count]} found<br>
          Webpack Config: #{debug_info[:webpack_config_exists] ? '✓' : '✗'}<br>
          Package.json: #{debug_info[:package_json_exists] ? '✓' : '✗'}
        </div>
      HTML
      
      html_safe_string(debug_html)
    end

    # Legacy UMD helper methods for backward compatibility with tests
    def umd_versions_debug
      return unless umd_debug_enabled?
      
      begin
        installed = IslandjsRails.core.send(:installed_packages)
        supported = installed.select { |pkg| IslandjsRails.core.send(:supported_package?, pkg) }
        
        if supported.empty?
          return %(<div style="position: fixed; bottom: 10px; right: 10px; background: #666; color: #fff; padding: 5px; font-size: 10px; z-index: 9999;">UMD: No packages</div>).html_safe
        end
        
        versions = supported.map do |package_name|
          begin
            version = IslandjsRails.version_for(package_name)
            "#{package_name}: #{version}"
          rescue
            "#{package_name}: error"
          end
        end.join(', ')
        
        %(<div style="position: fixed; bottom: 10px; right: 10px; background: #000; color: #fff; padding: 5px; font-size: 10px; z-index: 9999;">UMD: #{versions}</div>).html_safe
      rescue => e
        %(<div style="position: fixed; bottom: 10px; right: 10px; background: #f00; color: #fff; padding: 5px; font-size: 10px; z-index: 9999;">UMD Error: #{e.message}</div>).html_safe
      end
    end

    def umd_partial_for(package_name)
      # Backward compatibility: delegate to vendor UMD partial
      # Individual package partials are no longer used
      if Rails.env.development?
        "<!-- IslandJS: umd_partial_for('#{package_name}') is deprecated. Use island_partials or render 'shared/islands/vendor_umd' instead -->".html_safe
      else
        # In production, silently delegate to vendor partial
        render(partial: "shared/islands/vendor_umd").html_safe
      end
    rescue ActionView::MissingTemplate
      if Rails.env.development?
        "<!-- IslandJS: Vendor UMD partial missing. Run: rails islandjs:init -->".html_safe
      else
        "".html_safe
      end
    end

    def react_partials
      packages = ['react', 'react-dom']
      partials = packages.map { |pkg| umd_partial_for(pkg) }.compact.join("\n")
      html_safe_string(partials)
    end

    # Generate a script tag for vendor JavaScript files
    # Useful for including third-party libraries from the vendor directory
    def extra_vendor_tag(name, extension = ".min.js")
      "<script src='/vendor/#{name}#{extension}' data-turbo-track='reload'></script>".html_safe
    end

    private

    # Whether the floating UMD versions debug footer should render
    def umd_debug_enabled?
      return false unless Rails.env.development?

      env_value = ENV['ISLANDJS_RAILS_SHOW_UMD_DEBUG']
      return false if env_value.nil?

      %w[1 true yes on].include?(env_value.to_s.strip.downcase)
    end

    # Find the bundle file path (with manifest support)
    def find_bundle_path
      # Try manifest first (production) via configured path only
      manifest_path = IslandjsRails.configuration.manifest_path
      
      if File.exist?(manifest_path)
        begin
          manifest = JSON.parse(File.read(manifest_path))
          # Look for islands_bundle in manifest
          bundle_key = manifest.keys.find { |key| key.include?('islands_bundle') }
          return "/#{manifest[bundle_key]}" if bundle_key && manifest[bundle_key]
        rescue JSON::ParserError
          # Fall through to direct file check
        end
      end
      
      # Try direct file (development)
      direct_bundle_path = Rails.root.join('public', 'islands_bundle.js')
      if File.exist?(direct_bundle_path)
        return '/islands_bundle.js'
      end
      
      # Bundle not found
      nil
    end

    # Generate React component mounting script with Turbo compatibility
    def generate_react_mount_script(component_name, component_id, namespace, namespace_with_optional)
      <<~JAVASCRIPT
        <script>
          (function() {
            function mount#{component_name}() {
              const container = document.getElementById('#{component_id}');
              if (!container) return;
              
              // Check for component availability
              if (typeof #{namespace_with_optional} === 'undefined' || !#{namespace_with_optional}.#{component_name}) {
                console.warn('IslandJS: #{component_name} component not found. Make sure it\\'s exported in your bundle.');
                // Restore placeholder visibility if component fails to load
                const placeholder = container.querySelector('[data-island-placeholder="true"]');
                if (placeholder) {
                  placeholder.style.display = '';
                }
                return;
              }
              
              if (typeof React === 'undefined' || typeof window.ReactDOM === 'undefined') {
                console.warn('IslandJS: React or ReactDOM not loaded. Install with: rails "islandjs:install[react]" and rails "islandjs:install[react-dom]"');
                // Restore placeholder visibility if React fails to load
                const placeholder = container.querySelector('[data-island-placeholder="true"]');
                if (placeholder) {
                  placeholder.style.display = '';
                }
                return;
              }
              
              const props = { containerId: '#{component_id}' };
              const element = React.createElement(#{namespace_with_optional}.#{component_name}, props);
              
              try {
                // Use React 18 createRoot if available, fallback to React 17 render
                if (window.ReactDOM.createRoot) {
                  if (!container._reactRoot) {
                    container._reactRoot = window.ReactDOM.createRoot(container);
                  }
                  container._reactRoot.render(element);
                  // React 18 automatically clears container - no manual cleanup needed
                } else {
                  // React 17 - render is synchronous and clears container automatically
                  window.ReactDOM.render(element, container);
                }
              } catch (error) {
                console.error('IslandJS: Failed to mount #{component_name}:', error);
                // On error, keep placeholder visible by not modifying container
              }
            }
            
            function cleanup#{component_name}() {
              const container = document.getElementById('#{component_id}');
              if (!container) return;
              
              // React 18 unmount
              if (container._reactRoot) {
                container._reactRoot.unmount();
                container._reactRoot = null;
              } else if (typeof window.ReactDOM !== 'undefined' && window.ReactDOM.unmountComponentAtNode) {
                // React 17 unmount
                window.ReactDOM.unmountComponentAtNode(container);
              }
            }
            
            // Mount on page load and Turbo navigation
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', mount#{component_name});
            } else {
              mount#{component_name}();
            }
            
            // Turbo compatibility
            document.addEventListener('turbo:load', mount#{component_name});
            document.addEventListener('turbo:before-cache', cleanup#{component_name});
            document.addEventListener('turbo:render', mount#{component_name});
            document.addEventListener('turbo:before-render', cleanup#{component_name});
            
            // Legacy Turbolinks compatibility
            document.addEventListener('turbolinks:load', mount#{component_name});
            document.addEventListener('turbolinks:before-cache', cleanup#{component_name});
          })();
        </script>
      JAVASCRIPT
    end

    # Generate Vue component mounting script with Turbo compatibility
    def generate_vue_mount_script(component_name, component_id, props_json)
      <<~JAVASCRIPT
        <script>
          (function() {
            let vueApp = null;
            
            function mount#{component_name}() {
              if (typeof window.islandjsRails === 'undefined' || !window.islandjsRails.#{component_name}) {
                console.warn('IslandJS: #{component_name} component not found. Make sure it\\'s exported in your bundle.');
                return;
              }
              
              if (typeof Vue === 'undefined') {
                console.warn('IslandJS: Vue not loaded. Install with: rails "islandjs:install[vue]"');
                return;
              }
              
              const container = document.getElementById('#{component_id}');
              if (!container) return;
              
              const props = #{props_json};
              
              // Vue 3 syntax
              if (Vue.createApp) {
                vueApp = Vue.createApp({
                  render() {
                    return Vue.h(window.islandjsRails.#{component_name}, props);
                  }
                });
                vueApp.mount('##{component_id}');
              } else {
                // Vue 2 syntax
                vueApp = new Vue({
                  el: '##{component_id}',
                  render: function(h) {
                    return h(window.islandjsRails.#{component_name}, { props: props });
                  }
                });
              }
            }
            
            function unmount#{component_name}() {
              if (vueApp) {
                if (vueApp.unmount) {
                  // Vue 3
                  vueApp.unmount();
                } else if (vueApp.$destroy) {
                  // Vue 2
                  vueApp.$destroy();
                }
                vueApp = null;
              }
            }
            
            // Mount on page load and Turbo navigation
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', mount#{component_name});
            } else {
              mount#{component_name}();
            }
            
            // Turbo compatibility
            document.addEventListener('turbo:load', mount#{component_name});
            document.addEventListener('turbo:before-cache', unmount#{component_name});
            
            // Legacy Turbolinks compatibility
            document.addEventListener('turbolinks:load', mount#{component_name});
            document.addEventListener('turbolinks:before-cache', unmount#{component_name});
          })();
        </script>
      JAVASCRIPT
    end

    # Cross-Rails version html_safe compatibility
    def html_safe_string(string)
      if string.respond_to?(:html_safe)
        string.html_safe
      else
        string
      end
    end
  end
end

# Auto-include in ActionView if Rails is present
if defined?(ActionView::Base)
  ActionView::Base.include IslandjsRails::RailsHelpers
end
