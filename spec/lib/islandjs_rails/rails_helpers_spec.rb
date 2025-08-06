require_relative '../../spec_helper'
require 'islandjs_rails/rails_helpers'

RSpec.describe IslandjsRails::RailsHelpers do
  let(:temp_dir) { create_temp_dir }
  let(:view_context) { 
    Class.new do
      include IslandjsRails::RailsHelpers
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::AssetTagHelper
      
      def render(options)
        if options[:partial]
          case options[:partial]
          when 'shared/islands/react'
            '<script>React UMD content</script>'
          when 'shared/islands/lodash'
            '<script>Lodash UMD content</script>'
          else
            raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
          end
        end
      end
      
      def asset_path(path)
        "/assets/#{path}"
      end
      
      private
      
      def html_escape(value)
        ERB::Util.html_escape(value.to_s)
      end
    end.new
  }
  
  before do
    mock_rails_root(temp_dir)
    create_temp_package_json(temp_dir, {
      'react' => '^18.3.1',
      'react-dom' => '^18.3.1',
      'lodash' => '^4.17.21'
    })
    
    # Mock Rails environment
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
  end

  describe '#island_partials' do
    before do
      # Create some partials
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'islands')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
      
      # Mock the core methods
      allow(IslandjsRails.core).to receive(:send).with(:installed_packages).and_return(['react', 'react-dom', 'lodash'])
      allow(IslandjsRails.core).to receive(:send).with(:supported_package?, 'react').and_return(true)
      allow(IslandjsRails.core).to receive(:send).with(:supported_package?, 'react-dom').and_return(true)
      allow(IslandjsRails.core).to receive(:send).with(:supported_package?, 'lodash').and_return(true)
      
      # Mock the render method more precisely
      allow(view_context).to receive(:render) do |options|
        case options[:partial]
        when 'shared/islands/react'
          '<script>React UMD content</script>'
        when 'shared/islands/react_dom'
          raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
        when 'shared/islands/lodash'
          raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
        else
          raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
        end
      end
    end
    
    it 'renders vendor UMD partial' do
      # Mock the vendor UMD partial to exist
      allow(view_context).to receive(:render).with(partial: "shared/islands/vendor_umd").and_return('<script src="/islands/vendor/react-18.3.1.min.js"></script>')
      
      result = view_context.island_partials
      
      expect(result).to include('/islands/vendor/react-18.3.1.min.js')
    end
    
    it 'includes warning comments for missing vendor partial in development' do
      # Don't mock render - let it fail naturally
      result = view_context.island_partials
      
      expect(result).to include('Vendor UMD partial missing. Run: rails islandjs:init')
    end
  end

  describe '#umd_partial_for' do
    before do
      # Mock core methods
      allow(IslandjsRails.core).to receive(:send).with(:supported_package?, 'react').and_return(true)
      allow(IslandjsRails.core).to receive(:send).with(:supported_package?, 'vue').and_return(false)
      
      # Mock render method for vendor UMD partial
      allow(view_context).to receive(:render) do |options|
        case options[:partial]
        when 'shared/islands/vendor_umd'
          '<script>Vendor UMD content</script>'
        else
          raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
        end
      end
    end
    
    it 'returns deprecation warning in development' do
      result = view_context.umd_partial_for('react')
      expect(result).to include('umd_partial_for(\'react\') is deprecated')
      expect(result).to include('Use island_partials or render \'shared/islands/vendor_umd\' instead')
    end

    it 'returns deprecation warning for missing partials in development' do
      result = view_context.umd_partial_for('vue')
      expect(result).to include('umd_partial_for(\'vue\') is deprecated')
      expect(result).to include('Use island_partials or render \'shared/islands/vendor_umd\' instead')
    end

    it 'delegates to vendor partial in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      
      result = view_context.umd_partial_for('vue')
      expect(result).to include('Vendor UMD content')
    end

    it 'handles missing vendor partial gracefully in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(view_context).to receive(:render).and_raise(ActionView::MissingTemplate.new([], 'shared/islands/vendor_umd', [], true, "Missing template"))
      
      result = view_context.umd_partial_for('vue')
      expect(result).to eq('')
    end
  end

  describe 'environment handling' do
    it 'respects Rails environment for debug helpers' do
      # Test staging environment
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('staging'))
      
      result = view_context.umd_versions_debug
      expect(result).to be_nil
    end

    it 'handles test environment' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('test'))
      
      result = view_context.umd_versions_debug
      expect(result).to be_nil
    end
  end

  describe 'error edge cases' do
    it 'handles missing Rails.root gracefully' do
      # Mock configuration to handle nil Rails.root
      mock_config = double('config')
      allow(mock_config).to receive(:partials_dir).and_return(Pathname.new('/tmp'))
      allow(mock_config).to receive(:package_json_path).and_return(Pathname.new('/tmp/package.json'))
      allow(IslandjsRails).to receive(:configuration).and_return(mock_config)
      allow(IslandjsRails.core).to receive(:send).with(:installed_packages).and_return([])
      
      # Should not crash
      expect { view_context.island_partials }.not_to raise_error
    end

    it 'handles file system errors in island_bundle_script' do
      allow(File).to receive(:exist?).and_return(false)
      
      result = view_context.island_bundle_script
      
      expect(result).to include('/islands_bundle.js')
    end

    it 'handles JSON parsing errors gracefully' do
      manifest_path = File.join(temp_dir, 'public', 'islands_manifest.json')
      FileUtils.mkdir_p(File.dirname(manifest_path))
      File.write(manifest_path, 'invalid json{')
      
      result = view_context.island_bundle_script
      
      expect(result).to include('/islands_bundle.js')
    end
  end

  describe 'HTML escaping' do
    it 'properly escapes special characters in props' do
      result = view_context.react_component('TestComponent', { 
        message: '<script>alert("xss")</script>',
        quote: 'He said "hello"'
      })
      
      expect(result).to include('&lt;script&gt;alert(&quot;xss&quot;)&lt;/script&gt;')
      expect(result).to include('He said &quot;hello&quot;')
    end

    it 'handles nil props gracefully' do
      result = view_context.react_component('TestComponent', {
        value: nil,
        name: 'test'
      })
      
      expect(result).to include('data-value=""')
      expect(result).to include('data-name="test"')
    end

    it 'converts complex prop names correctly' do
      result = view_context.react_component('TestComponent', {
        userName: 'john',
        user_email: 'john@example.com',
        'api-key': 'secret'
      })
      
      expect(result).to include('data-user-name="john"')
      expect(result).to include('data-user-email="john@example.com"')
      expect(result).to include('data-api-key="secret"')
    end
  end

  describe 'React component variations' do
    it 'handles empty props' do
      result = view_context.react_component('EmptyComponent', {})
      
      expect(result).to match(/id="react-empty-component-[a-f0-9]{8}"/)
      expect(result).to include('const props = { containerId:')
      expect(result).to include('data-initial-state="{}"')
    end

    it 'supports custom namespaces' do
      result = view_context.react_component('CustomComponent', {}, {
        namespace: 'window.MyApp.Components'
      })
      
      expect(result).to include('window.MyApp.Components?.CustomComponent')
    end

    it 'generates unique container IDs' do
      result1 = view_context.react_component('Component1', {})
      result2 = view_context.react_component('Component2', {})
      
      expect(result1).to match(/id="react-component1-[a-f0-9]{8}"/)
      expect(result2).to match(/id="react-component2-[a-f0-9]{8}"/)
    end
  end

  describe '#react_partials' do
    it 'returns deprecation warnings for React and ReactDOM' do
      result = view_context.react_partials
      
      expect(result).to include('umd_partial_for(\'react\') is deprecated')
      expect(result).to include('umd_partial_for(\'react-dom\') is deprecated')
      expect(result).to include('Use island_partials or render \'shared/islands/vendor_umd\' instead')
    end
  end

  describe '#react_component' do
    let(:props) { { userId: 123, theme: 'dark' } }
    
    it 'generates React component container and script' do
      result = view_context.react_component('MyComponent', props)
      
      expect(result).to match(/id="react-my-component-[a-f0-9]{8}"/)
      expect(result).to include('data-user-id="123"')
      expect(result).to include('data-theme="dark"')
      expect(result).to include('data-initial-state=')
      expect(result).to include('window.islandjsRails.MyComponent')
      expect(result).to include('function mountMyComponent()')
      expect(result).to include('function cleanupMyComponent()')
    end
    
    it 'allows custom container ID and namespace' do
      options = { container_id: 'custom-container', namespace: 'window.MyApp' }
      result = view_context.react_component('Widget', {}, options)
      
      expect(result).to include('id="custom-container"')
      expect(result).to include('window.MyApp?.Widget')
    end
    
    it 'includes Turbo event listeners' do
      result = view_context.react_component('MyComponent', {})
      
      expect(result).to include("addEventListener('turbo:load'")
      expect(result).to include("addEventListener('turbo:render'")
      expect(result).to include("addEventListener('turbo:before-render'")
      expect(result).to include("addEventListener('turbo:before-cache'")
    end
    
    it 'supports both React 18 createRoot and legacy render' do
      result = view_context.react_component('MyComponent', {})
      
      expect(result).to include('window.ReactDOM.createRoot')
      expect(result).to include('container._reactRoot')
      expect(result).to include('window.ReactDOM.render')
    end
    
    it 'properly escapes HTML in props' do
      props = { message: '<script>alert("xss")</script>' }
      result = view_context.react_component('MyComponent', props)
      
      expect(result).to include('&lt;script&gt;')
      expect(result).not_to include('<script>alert("xss")</script>')
    end
  end

  describe '#island_bundle_script' do
    let(:manifest_path) { File.join(temp_dir, 'public', 'islands_manifest.json') }
    
    before do
      FileUtils.mkdir_p(File.dirname(manifest_path))
    end
    
    it 'uses webpack manifest when available' do
      manifest = { 'islands_bundle.js' => '/islandjs_rails_bundle.abc123.js' }
      File.write(manifest_path, JSON.generate(manifest))
      
      result = view_context.island_bundle_script
      
      expect(result).to include('/islandjs_rails_bundle.abc123.js')
    end
    
    it 'uses islands_bundle.js from manifest' do
      manifest = { 
        'islands_bundle.js' => '/islandjs_rails_bundle.def456.js',
        'other_bundle.js' => '/other_bundle.abc123.js' 
      }
      File.write(manifest_path, JSON.generate(manifest))
      
      result = view_context.island_bundle_script
      
      expect(result).to include('/islandjs_rails_bundle.def456.js')
    end
    
    it 'falls back to islands_bundle.js when no manifest' do
      result = view_context.island_bundle_script
      
      expect(result).to include('/islands_bundle.js')
    end
    
    it 'handles invalid JSON gracefully' do
      File.write(manifest_path, 'invalid json{')
      
      result = view_context.island_bundle_script
      
      expect(result).to include('/islands_bundle.js')
    end
  end

  describe '#islands' do
    it 'includes both partials and bundle script' do
      result = view_context.islands
      
      expect(result).to be_html_safe
      expect(result).to_not be_empty
    end
  end

  describe '#umd_versions_debug' do
    it 'shows debug info in development' do
      # Mock the core.installed_packages method and supported_package? calls
      allow(IslandjsRails.core).to receive(:send).with(:installed_packages).and_return(['react', 'lodash'])
      allow(IslandjsRails.core).to receive(:send).with(:supported_package?, 'react').and_return(true)
      allow(IslandjsRails.core).to receive(:send).with(:supported_package?, 'lodash').and_return(true)
      allow(IslandjsRails).to receive(:version_for).with('react').and_return('18.3.1')
      allow(IslandjsRails).to receive(:version_for).with('lodash').and_return('4.17.21')
      
      result = view_context.umd_versions_debug
      
      expect(result).to include('react: 18.3.1')
      expect(result).to include('lodash: 4.17.21')
    end
    
    it 'returns nothing in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      
      result = view_context.umd_versions_debug
      expect(result).to be_nil
    end
    
    it 'shows error message when debugging fails' do
      # Mock the core.installed_packages to raise an error at the method level
      allow(IslandjsRails.core).to receive(:send).with(:installed_packages).and_raise(StandardError.new('Test error'))
      
      result = view_context.umd_versions_debug
      
      expect(result).to include('UMD Error: Test error')
    end
  end
end 