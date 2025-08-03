module IslandjsRails
  module RailsHelpers
    # Main helper method to render all island partials and bundle script
    def islands
      island_partials + island_bundle_script
    end

    # Render all island partials (CDN scripts for external libraries)
    def island_partials
      return '' unless Dir.exist?(IslandjsRails.configuration.partials_dir)
      
      partials = Dir.glob(File.join(IslandjsRails.configuration.partials_dir, '*.html.erb'))
      
      if partials.empty?
        return html_safe_string("<!-- No IslandJS partials found -->")
      end
      
      rendered_partials = partials.map do |partial_path|
        partial_name = File.basename(partial_path, '.html.erb')
        render(partial: "shared/islands/#{partial_name}")
      end.join("\n")
      
      html_safe_string(rendered_partials)
    end

    # Render the main IslandJS bundle script tag
    def island_bundle_script
      bundle_path = find_bundle_path
      
      unless bundle_path
        return html_safe_string("<!-- IslandJS bundle not found. Run 'rails islandjs:build' -->")
      end
      
      script_tag = "<script src=\"#{bundle_path}\" defer></script>"
      html_safe_string(script_tag)
    end

    # Mount a React component with props and Turbo-compatible lifecycle
    def react_component(component_name, props = {}, options = {})
      # Generate unique ID for this component instance
      component_id = "react-#{component_name.downcase}-#{SecureRandom.hex(4)}"
      
      # Prepare props as JSON
      props_json = props.to_json
      
      # Extract options
      tag_name = options[:tag] || 'div'
      css_class = options[:class] || ''
      
      # Generate the mounting script
      mount_script = generate_react_mount_script(component_name, component_id, props_json)
      
      # Return the container div and script
      container_html = "<#{tag_name} id=\"#{component_id}\" class=\"#{css_class}\"></#{tag_name}>"
      
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

    private

    # Find the bundle file path (with manifest support)
    def find_bundle_path
      # Try manifest first (production)
      manifest_path = Rails.root.join('public', 'islandjsRailsManifest.json')
      
      if File.exist?(manifest_path)
        begin
          manifest = JSON.parse(File.read(manifest_path))
          bundle_key = manifest.keys.find { |key| key.include?('islandjsRailsBundle') }
          return "/#{manifest[bundle_key]}" if bundle_key && manifest[bundle_key]
        rescue JSON::ParserError
          # Fall through to direct file check
        end
      end
      
      # Try direct file (development)
      direct_bundle_path = Rails.root.join('public', 'islandjsRailsBundle.js')
      return '/islandjsRailsBundle.js' if File.exist?(direct_bundle_path)
      
      # Bundle not found
      nil
    end

    # Generate React component mounting script with Turbo compatibility
    def generate_react_mount_script(component_name, component_id, props_json)
      <<~JAVASCRIPT
        <script>
          (function() {
            function mount#{component_name}() {
              if (typeof window.islandjsRails === 'undefined' || !window.islandjsRails.#{component_name}) {
                console.warn('IslandJS: #{component_name} component not found. Make sure it\\'s exported in your bundle.');
                return;
              }
              
              if (typeof React === 'undefined' || typeof ReactDOM === 'undefined') {
                console.warn('IslandJS: React or ReactDOM not loaded. Install with: rails "islandjs:install[react]" and rails "islandjs:install[react-dom]"');
                return;
              }
              
              const container = document.getElementById('#{component_id}');
              if (!container) return;
              
              const props = #{props_json};
              const element = React.createElement(window.islandjsRails.#{component_name}, props);
              
              // Use React 18 createRoot if available, fallback to React 17 render
              if (ReactDOM.createRoot) {
                if (!container._reactRoot) {
                  container._reactRoot = ReactDOM.createRoot(container);
                }
                container._reactRoot.render(element);
              } else {
                ReactDOM.render(element, container);
              }
            }
            
            function unmount#{component_name}() {
              const container = document.getElementById('#{component_id}');
              if (!container) return;
              
              // React 18 unmount
              if (container._reactRoot) {
                container._reactRoot.unmount();
                container._reactRoot = null;
              } else if (typeof ReactDOM !== 'undefined' && ReactDOM.unmountComponentAtNode) {
                // React 17 unmount
                ReactDOM.unmountComponentAtNode(container);
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
