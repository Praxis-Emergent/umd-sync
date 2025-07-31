module UmdSync
  module RailsHelpers
    # Render all UMD partials for installed packages
    # Usage: <%= umd_partials %>
    def umd_partials
      output = []
      
      UmdSync.core.send(:installed_packages).each do |package_name|
        if UmdSync.core.send(:supported_package?, package_name)
          partial_name = "shared/umd/#{package_name.gsub(/[@\/]/, '_').gsub(/-/, '_')}"
          
          begin
            output << render(partial: partial_name)
          rescue ActionView::MissingTemplate
            # Partial doesn't exist, skip silently or show warning in development
            if Rails.env.development?
              output << "<!-- UmdSync: Missing partial for #{package_name}. Run: rails umd_sync:sync -->"
            end
          end
        end
      end
      
      output.join("\n").html_safe
    end

    # Render specific UMD partial
    # Usage: <%= umd_partial_for('react') %>
    def umd_partial_for(package_name)
      unless UmdSync.core.send(:supported_package?, package_name)
        return "<!-- UmdSync: Unsupported package #{package_name} -->".html_safe if Rails.env.development?
        return "".html_safe
      end
      
      partial_name = "shared/umd/#{package_name.gsub(/[@\/]/, '_').gsub(/-/, '_')}"
      
      begin
        render(partial: partial_name).html_safe
      rescue ActionView::MissingTemplate
        if Rails.env.development?
          "<!-- UmdSync: Missing partial for #{package_name}. Run: rails umd_sync:sync -->".html_safe
        else
          "".html_safe
        end
      end
    end

    # React partials helper - renders React and ReactDOM partials
    def react_partials
      output = []
      output << umd_partial_for('react') if UmdSync.package_installed?('react')
      output << umd_partial_for('react-dom') if UmdSync.package_installed?('react-dom')
      output.join("\n").html_safe
    end

    # Mount a React component with Turbo-compatible lifecycle
    # Usage: <%= react_component('DashboardApp', { userId: current_user.id }, container_id: 'dashboard-app') %>
    def react_component(component_name, props = {}, options = {})
      container_id = options[:container_id] || "react-#{component_name.underscore.dasherize}"
      namespace = options[:namespace] || 'window.umd_sync_react'
      
      # Convert props to data attributes (camelCase -> kebab-case)
      data_attrs = props.map do |key, value|
        attr_name = key.to_s.underscore.dasherize
        "data-#{attr_name}=\"#{html_escape(value)}\""
      end.join(' ')
      
      # Generate the container and mounting script
      <<~HTML.html_safe
        <div id="#{container_id}" #{data_attrs}></div>
        
        <script>
          (function() {
            function cleanup#{component_name}() {
              const container = document.getElementById('#{container_id}');
              if (container && window.React && window.ReactDOM) {
                if (window.ReactDOM.createRoot && container._reactRoot) {
                  container._reactRoot.unmount();
                  delete container._reactRoot;
                } else if (window.ReactDOM.unmountComponentAtNode) {
                  window.ReactDOM.unmountComponentAtNode(container);
                }
                container.dataset.mounted = '';
              }
            }

            function mount#{component_name}() {
              const container = document.getElementById('#{container_id}');
              if (!container || !window.React || !window.ReactDOM || !#{namespace}?.#{component_name} || container.dataset.mounted) {
                return;
              }

              // Extract props from data attributes
              const props = {};
              #{generate_prop_extraction(props)}

              // Render component
              if (window.ReactDOM.createRoot) {
                const root = window.ReactDOM.createRoot(container);
                root.render(window.React.createElement(#{namespace}.#{component_name}, props));
                container._reactRoot = root;
              } else {
                window.ReactDOM.render(
                  window.React.createElement(#{namespace}.#{component_name}, props),
                  container
                );
              }

              container.dataset.mounted = 'true';
            }

            // Turbo event listeners
            document.addEventListener('turbo:load', mount#{component_name});
            document.addEventListener('turbo:render', mount#{component_name});
            document.addEventListener('turbo:before-render', cleanup#{component_name});
            document.addEventListener('turbo:before-cache', cleanup#{component_name});
            
            // Try to mount immediately if DOM is ready
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', mount#{component_name});
            } else {
              mount#{component_name}();
            }
          })();
        </script>
      HTML
    end

    # Display current library versions (useful for debugging)
    def umd_versions_debug
      return unless Rails.env.development?
      
      installed = UmdSync.core.send(:installed_packages)
      supported = installed.select { |pkg| UmdSync.core.send(:supported_package?, pkg) }
      
      if supported.empty?
        return %(<div style="position: fixed; bottom: 10px; right: 10px; background: #666; color: #fff; padding: 5px; font-size: 10px; z-index: 9999;">UMD: No packages</div>).html_safe
      end
      
      versions = supported.map do |package_name|
        begin
          version = UmdSync.version_for(package_name)
          "#{package_name}: #{version}"
        rescue
          "#{package_name}: error"
        end
      end.join(', ')
      
      %(<div style="position: fixed; bottom: 10px; right: 10px; background: #000; color: #fff; padding: 5px; font-size: 10px; z-index: 9999;">UMD: #{versions}</div>).html_safe
    rescue => e
      %(<div style="position: fixed; bottom: 10px; right: 10px; background: #f00; color: #fff; padding: 5px; font-size: 10px; z-index: 9999;">UMD Error: #{e.message}</div>).html_safe
    end

    # Render the webpack bundle script tag
    # Usage: <%= umd_bundle_script %>
    def umd_bundle_script
      manifest_path = Rails.root.join('public/assets/manifest.json')
      
      unless File.exist?(manifest_path)
        # Fallback to standard application.js when no manifest
        return %(<script src="#{asset_path('application.js')}"></script>).html_safe
      end
      
      begin
        manifest = JSON.parse(File.read(manifest_path))
        # Look for application.js first, then bundle.js as fallback
        bundle_path = manifest['application.js'] || manifest['bundle.js']
        
        if bundle_path
          %(<script src="#{asset_path(bundle_path)}"></script>).html_safe
        else
          "<!-- UmdSync: No bundle.js in manifest -->".html_safe
        end
      rescue JSON::ParserError
        "<!-- UmdSync: Invalid webpack manifest -->".html_safe
      end
    end

    # Complete UMD setup: partials + bundle
    # Usage: <%= umd_complete %>
    def umd_complete
      output = []
      output << "<!-- UmdSync: UMD Libraries -->"
      output << umd_partials
      output << "<!-- UmdSync: Application Bundle -->"
      output << umd_bundle_script
      output.join("\n").html_safe
    end

    # Debug info helper - shows UmdSync status in development
    def umd_debug_info
      return '' if Rails.env.production?
      
      begin
        installed = UmdSync.core.send(:installed_packages)
        debug_info = installed.map do |package|
          version = UmdSync.version_for(package)
          has_partial = File.exist?(UmdSync.core.send(:partial_path_for, package))
          status = has_partial ? '✓' : '❌'
          "#{status} #{package}@#{version}"
        end.join('<br>')
        
        "<div style='position:fixed;bottom:10px;right:10px;background:rgba(0,0,0,0.8);color:white;padding:10px;font-size:12px;z-index:9999;'>UmdSync Debug:<br>#{debug_info}</div>".html_safe
      rescue => e
        "<div style='position:fixed;bottom:10px;right:10px;background:rgba(255,0,0,0.8);color:white;padding:10px;font-size:12px;z-index:9999;'>UmdSync Error: #{e.message}</div>".html_safe
      end
    end

    private

    def package_installed?(package_name)
      UmdSync.core.send(:installed_packages).include?(package_name)
    end

    def html_escape(value)
      case value
      when String
        ERB::Util.html_escape(value)
      when Numeric, TrueClass, FalseClass
        value.to_s
      else
        ERB::Util.html_escape(value.to_s)
      end
    end

    def generate_prop_extraction(props)
      return "" if props.empty?
      
      props.keys.map do |key|
        data_attr = key.to_s.camelize(:lower)
        "if (container.dataset.#{data_attr}) props.#{key} = container.dataset.#{data_attr};"
      end.join("\n              ")
    end
  end
end

# Auto-include in ActionView if Rails is present
if defined?(ActionView::Base)
  ActionView::Base.include UmdSync::RailsHelpers
end 