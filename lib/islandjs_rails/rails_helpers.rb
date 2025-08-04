module IslandjsRails
  module RailsHelpers
    def islands(*package_names)
      return '' unless Rails.env.development?
      
      island_partials(*package_names).html_safe
    end

    def react_component(component_name, props = {}, options = {})
      component_id = options[:id] || "react_#{SecureRandom.hex(4)}"
      namespace = options[:namespace]
      
      # Sanitize props for security
      safe_props = sanitize_component_props(props)
      
      container_html = content_tag(:div, "", 
        id: component_id,
        class: "react-island",
        data: {
          component: component_name,
          namespace: namespace
        }
      )
      
      mount_script = generate_secure_react_mount_script(component_name, component_id, safe_props, namespace)
      
      (container_html + mount_script).html_safe
    end

    def vue_component(component_name, props = {}, options = {})
      component_id = options[:id] || "vue_#{SecureRandom.hex(4)}"
      props_json = props.to_json
      
      container_html = content_tag(:div, "", id: component_id, class: "vue-island")
      
      mount_script = content_tag(:script, <<~JAVASCRIPT.html_safe)
        (function() {
          function mountVue() {
            if (typeof Vue === 'undefined') {
              console.warn('Vue is not loaded. Make sure to include Vue UMD.');
              return;
            }
            
            const container = document.getElementById('#{component_id}');
            if (!container) return;
            
            if (container.hasChildNodes()) return;
            
            new Vue({
              el: '##{component_id}',
              data: #{props_json},
              template: '<#{component_name.underscore.dasherize} v-bind="$data"></#{component_name.underscore.dasherize}>'
            });
          }
          
          if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', mountVue);
          } else {
            mountVue();
          }
          
          document.addEventListener('turbo:load', mountVue);
          document.addEventListener('turbolinks:load', mountVue);
        })();
      JAVASCRIPT
      
      (container_html + mount_script).html_safe
    end

    def island_component(component_name, framework, props = {}, options = {})
      case framework.to_s.downcase
      when 'react'
        react_component(component_name, props, options)
      when 'vue'
        vue_component(component_name, props, options)
      else
        "<!-- Unsupported framework: #{framework} -->".html_safe
      end
    end

    def island_debug
      return '' unless Rails.env.development?
      
      begin
        installed = IslandjsRails.status!
        
        debug_info = "<div style='background: #f0f0f0; padding: 10px; margin: 10px; border: 1px solid #ccc;'>"
        debug_info += "<h4>🏝️ IslandJS Rails Debug</h4>"
        debug_info += "<pre>#{installed}</pre>"
        debug_info += "</div>"
        
        debug_info.html_safe
      rescue => e
        "<!-- IslandJS Debug Error: #{e.message} -->".html_safe
      end
    end

    def umd_versions_debug
      return '' unless Rails.env.development?
      
      begin
        versions = []
        Dir.glob(IslandjsRails.configuration.partials_dir.join('_*.html.erb')).each do |partial|
          package_name = File.basename(partial, '.html.erb').sub(/^_/, '')
          version = IslandjsRails.version_for(package_name)
          versions << "#{package_name}: #{version || 'unknown'}"
        end
        
        if versions.any?
          debug_html = "<div style='background: #e6f3ff; padding: 8px; margin: 5px; font-family: monospace; font-size: 12px;'>"
          debug_html += "<strong>UMD Versions:</strong><br/>"
          debug_html += versions.join('<br/>')
          debug_html += "</div>"
          debug_html.html_safe
        else
          ''
        end
      rescue => e
        "<!-- UMD Debug Error: #{e.message} -->".html_safe
      end
    end

    def umd_partial_for(package_name)
      return '' unless package_name
      
      partial_path = package_name.gsub(/[^a-zA-Z0-9_-]/, '_')
      
      begin
        if IslandjsRails.has_partial?(package_name)
          render partial: "shared/islands/#{partial_path}"
        else
          if Rails.env.development?
            "<!-- Warning: UMD partial for '#{package_name}' not found. Run: rails islandjs:sync -->".html_safe
          else
            ''.html_safe
          end
        end
      rescue => e
        if Rails.env.development?
          "<!-- Error rendering UMD partial for #{package_name}: #{e.message} -->".html_safe
        else
          ''.html_safe
        end
      end
    end

    def island_partials(*package_names)
      if package_names.empty?
        package_names = Dir.glob(IslandjsRails.configuration.partials_dir.join('_*.html.erb'))
                          .map { |f| File.basename(f, '.html.erb').sub(/^_/, '') }
      end
      
      partials_html = package_names.map { |name| umd_partial_for(name) }.join("\n")
      bundle_script = island_bundle_script
      
      (partials_html + bundle_script).html_safe
    end

    def island_bundle_script
      bundle_path = find_bundle_path
      return '' unless bundle_path
      
      content_tag(:script, '', src: bundle_path, defer: true)
    end

    def find_bundle_path
      manifest_path = Rails.root.join('public', 'islands_manifest.json')
      
      if File.exist?(manifest_path)
        begin
          manifest = JSON.parse(File.read(manifest_path))
          bundle_file = manifest['islands_bundle.js']
          # Bundle file might already include leading slash
          return bundle_file if bundle_file && bundle_file.start_with?('/')
          return "/#{bundle_file}" if bundle_file
        rescue JSON::ParserError
          # Fall through to direct bundle check
        end
      end
      
      direct_bundle = Rails.root.join('public', 'islands_bundle.js')
      return '/islands_bundle.js' if File.exist?(direct_bundle)
      
      nil
    end

    private

    def sanitize_component_props(props)
      return {} unless props.is_a?(Hash)
      
      props.reject { |key, value| 
        sensitive_key?(key) || 
        unsafe_value?(value)
      }
    end

    def sensitive_key?(key)
      key_str = key.to_s.downcase
      %w[password token secret api_key auth session csrf].any? { |sensitive| 
        key_str.include?(sensitive) 
      }
    end

    def unsafe_value?(value)
      value.is_a?(Proc) || 
      value.respond_to?(:call) ||
      (defined?(ActiveRecord::Base) && value.is_a?(ActiveRecord::Base)) ||
      (value.is_a?(Object) && value.class.name.include?('ActiveRecord'))
    end

    def generate_secure_react_mount_script(component_name, component_id, props, namespace = nil)
      # Always use inline scripts in development for simplicity
      # Only use external scripts in production for full CSP compliance
      if Rails.env.production?
        external_script_path = Rails.root.join('public', 'islands', 'mount', "#{component_name.underscore}.js")
        if File.exist?(external_script_path)
          generate_external_mount_script(component_name, component_id, props, namespace)
        else
          # Fall back to inline script with nonce if external script doesn't exist
          generate_inline_mount_script_with_nonce(component_name, component_id, props, namespace)
        end
      else
        # Development: always use inline script with nonce for simplicity
        generate_inline_mount_script_with_nonce(component_name, component_id, props, namespace)
      end
    end

    def generate_external_mount_script(component_name, component_id, props, namespace)
      # In production, use external script files for full CSP compliance
      script_path = asset_path("/islands/mount/#{component_name.underscore}.js")
      
      content_tag(:script, '', 
        src: script_path,
        data: {
          island_id: component_id,
          component: component_name,
          props: props.to_json,
          namespace: namespace
        },
        defer: true
      )
    end

    def generate_inline_mount_script_with_nonce(component_name, component_id, props, namespace)
      namespace_prefix = namespace ? "window.#{namespace}" : "window.islandjsRails"
      props_json = html_safe_string(props.to_json)
      
      # Generate CSP nonce for inline scripts
      nonce = content_security_policy_nonce if respond_to?(:content_security_policy_nonce)

      content_tag(:script, <<~JAVASCRIPT.html_safe, nonce: nonce)
          (function() {
          // IslandJS Rails 8 + Turbo Compatible State Manager
          if (!window.IslandjsRails) {
            window.IslandjsRails = {
              components: new Map(),
              formStates: new Map(),
              scrollPositions: new Map()
            };
          }

          const IslandStateManager = {
            saveState: function(islandId, state) {
              try {
                const safeState = this.sanitizeState(state);
                sessionStorage.setItem('island_' + islandId, JSON.stringify(safeState));
                
                // Check sessionStorage size limits
                if (this.getStorageSize() > 4.5 * 1024 * 1024) { // 4.5MB limit
                  this.cleanupOldStates();
                }
              } catch (e) {
                console.warn('IslandJS: Failed to save state', e);
                this.handleStorageError(e);
              }
            },
            
            restoreState: function(islandId) {
              try {
                const stored = sessionStorage.getItem('island_' + islandId);
                return stored ? JSON.parse(stored) : null;
              } catch (e) {
                console.warn('IslandJS: Failed to restore state', e);
                this.handleStorageError(e);
                return null;
              }
            },
            
            sanitizeState: function(state) {
              const safe = {};
              for (const [key, value] of Object.entries(state || {})) {
                if (this.isSafeValue(value) && !this.isSensitive(key)) {
                  safe[key] = value;
                }
              }
              return safe;
            },
            
            isSafeValue: function(value) {
              return typeof value === 'string' || 
                     typeof value === 'number' || 
                     typeof value === 'boolean' ||
                     Array.isArray(value) ||
                     (typeof value === 'object' && value !== null && value.constructor === Object);
            },
            
            isSensitive: function(key) {
              const keyStr = String(key).toLowerCase();
              return ['password', 'token', 'secret', 'api_key', 'auth', 'session', 'csrf'].some(s => keyStr.includes(s));
            },
            
            getStorageSize: function() {
              let total = 0;
              for (const key in sessionStorage) {
                if (key.startsWith('island_')) {
                  total += sessionStorage[key].length;
                }
              }
              return total;
            },
            
            cleanupOldStates: function() {
              const keys = Object.keys(sessionStorage).filter(k => k.startsWith('island_'));
              // Remove oldest 25% of stored states
              const removeCount = Math.floor(keys.length * 0.25);
              keys.slice(0, removeCount).forEach(key => sessionStorage.removeItem(key));
            },
            
            handleStorageError: function(error) {
              if (error.name === 'QuotaExceededError') {
                this.cleanupOldStates();
              }
            }
          };

          // Form state preservation for Rails forms
          const FormStateManager = {
            preserve: function(container) {
              const forms = container.querySelectorAll('form');
              forms.forEach(form => {
                const formData = new FormData(form);
                const state = Object.fromEntries(formData.entries());
                window.IslandjsRails.formStates.set(form.id || form.action, state);
              });
            },
            
            restore: function(container) {
              const forms = container.querySelectorAll('form');
              forms.forEach(form => {
                const state = window.IslandjsRails.formStates.get(form.id || form.action);
                if (state) {
                  Object.entries(state).forEach(([name, value]) => {
                    const input = form.querySelector(`[name="${name}"]`);
                    if (input) input.value = value;
                  });
                }
              });
            }
          };

          // Focus management
          const FocusManager = {
            preserve: function() {
              const activeElement = document.activeElement;
              if (activeElement && activeElement.id) {
                sessionStorage.setItem('island_focus', activeElement.id);
              }
            },
            
            restore: function() {
              const focusId = sessionStorage.getItem('island_focus');
              if (focusId) {
                const element = document.getElementById(focusId);
                if (element) {
                  requestAnimationFrame(() => element.focus());
                }
                sessionStorage.removeItem('island_focus');
              }
            }
          };

          function mount#{component_name}() {
            if (typeof React === 'undefined' || typeof ReactDOM === 'undefined') {
              console.warn('React or ReactDOM not loaded for #{component_name}');
                return;
              }
              
              const container = document.getElementById('#{component_id}');
              if (!container) return;
              
            // Prevent double mounting
            if (container.hasChildNodes() && container._reactRoot) return;
              
            // Restore form state if present
            FormStateManager.restore(container);

            // Try to restore component state from sessionStorage
            let props;
            const restoredState = IslandStateManager.restoreState('#{component_id}');
            if (restoredState) {
              props = { ...#{props_json}, ...restoredState };
              console.debug('IslandJS: Restored state for #{component_name}');
            } else {
              props = #{props_json};
                  }

            const namespace = #{namespace_prefix};
            if (!namespace || !namespace.#{component_name}) {
              console.error('Component #{component_name} not found in namespace');
              return;
            }

            const element = React.createElement(namespace.#{component_name}, props);

            try {
              // React 18 vs legacy rendering
              if (ReactDOM.createRoot) {
                const root = ReactDOM.createRoot(container);
                root.render(element);
                container._reactRoot = root;
              } else {
                ReactDOM.render(element, container);
                container._reactRoot = true;
              }
              
              // Register component for cleanup
              window.IslandjsRails.components.set('#{component_id}', {
                container: container,
                root: container._reactRoot,
                componentName: '#{component_name}'
              });
              
            } catch (error) {
              console.error('IslandJS: Failed to mount #{component_name}', error);
              // Fallback: show error message to user
              container.innerHTML = '<div style="color: red; padding: 10px;">Component failed to load</div>';
              }
            }
            
          function cleanup#{component_name}() {
            const container = document.getElementById('#{component_id}');
            if (!container) return;
            
            try {
              // Preserve form state before cleanup
              FormStateManager.preserve(container);
              
              // Clean up React component
              if (container._reactRoot) {
                if (container._reactRoot.unmount) {
                  container._reactRoot.unmount();
                } else if (typeof ReactDOM !== 'undefined') {
                  ReactDOM.unmountComponentAtNode(container);
                }
                container._reactRoot = null;
              }
              
              // Remove from component registry
              window.IslandjsRails.components.delete('#{component_id}');
              
            } catch (error) {
              console.warn('IslandJS: Cleanup error for #{component_name}', error);
            }
          }

          function handleBeforeVisit#{component_name}() {
            const container = document.getElementById('#{component_id}');
            if (container) {
              FocusManager.preserve();
              FormStateManager.preserve(container);
            }
          }

          function handleVisit#{component_name}() {
            // Component will be cleaned up and remounted
            cleanup#{component_name}();
              }

          function handleFrameLoad#{component_name}() {
            // Remount if container exists but component is unmounted
            const container = document.getElementById('#{component_id}');
            if (container && !container._reactRoot) {
              mount#{component_name}();
            }
          }

          // Complete Turbo event handling for Rails 8 compatibility
            if (document.readyState === 'loading') {
              document.addEventListener('DOMContentLoaded', mount#{component_name});
            } else {
              mount#{component_name}();
            }
            
          // Core Turbo Drive events
            document.addEventListener('turbo:load', mount#{component_name});
          document.addEventListener('turbo:before-cache', cleanup#{component_name});
          document.addEventListener('turbo:render', mount#{component_name});
          document.addEventListener('turbo:before-render', cleanup#{component_name});
          
          // Additional Turbo events for complete compatibility
          document.addEventListener('turbo:before-visit', handleBeforeVisit#{component_name});
          document.addEventListener('turbo:visit', handleVisit#{component_name});
          document.addEventListener('turbo:frame-load', handleFrameLoad#{component_name});
          
          // Legacy Turbolinks support
            document.addEventListener('turbolinks:load', mount#{component_name});
          document.addEventListener('turbolinks:before-cache', cleanup#{component_name});
          
          // Restore focus after mount
          document.addEventListener('turbo:load', FocusManager.restore);
          })();
      JAVASCRIPT
    end

    def html_safe_string(str)
      str.gsub('</script>', '<\/script>').html_safe
    end

    private

    def import_maps_enabled?
      defined?(Rails.application.importmap) && Rails.application.importmap.present?
    rescue
      false
    end

    def asset_path(path)
      if respond_to?(:asset_url)
        asset_url(path)
      elsif defined?(Rails.application.config.asset_host) && Rails.application.config.asset_host
        "#{Rails.application.config.asset_host}#{path}"
      else
        path
      end
    end
  end
end

# Auto-include in ActionView if Rails is present
if defined?(ActionView::Base)
  ActionView::Base.include IslandjsRails::RailsHelpers
end
