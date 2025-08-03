require 'spec_helper'

RSpec.describe UmdSync::RailsHelpers do
  let(:temp_dir) { create_temp_dir }
  let(:view_context) { 
    Class.new do
      include UmdSync::RailsHelpers
      include ActionView::Helpers::TagHelper
      include ActionView::Helpers::AssetTagHelper
      
      def render(options)
        if options[:partial]
          case options[:partial]
          when 'shared/umd/react'
            '<script>React UMD content</script>'
          when 'shared/umd/lodash'
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

  describe '#umd_partials' do
    before do
      # Create some partials
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'umd')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
      
      # Mock the render method more precisely
      allow(view_context).to receive(:render) do |options|
        case options[:partial]
        when 'shared/umd/react'
          '<script>React UMD content</script>'
        when 'shared/umd/react_dom'
          raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
        when 'shared/umd/lodash'
          raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
        else
          raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
        end
      end
    end
    
    it 'renders available UMD partials' do
      result = view_context.umd_partials
      
      expect(result).to include('React UMD content')
    end
    
    it 'includes warning comments for missing partials in development' do
      result = view_context.umd_partials
      
      expect(result).to include('Missing partial for react-dom')
      expect(result).to include('Missing partial for lodash')
      expect(result).to include('rails umd_sync:sync')
    end
  end

  describe '#umd_partial_for' do
    before do
      # Mock render method for specific partial
      allow(view_context).to receive(:render) do |options|
        case options[:partial]
        when 'shared/umd/react'
          '<script>React UMD content</script>'
        else
          raise ActionView::MissingTemplate.new([], options[:partial], [], true, "Missing template")
        end
      end
    end
    
    it 'renders specific partial when available' do
      result = view_context.umd_partial_for('react')
      expect(result).to include('React UMD content')
    end

    it 'returns warning comment for missing partials in development' do
      result = view_context.umd_partial_for('vue')
      expect(result).to include('Missing partial for vue')
      expect(result).to include('rails umd_sync:sync')
    end

    it 'returns empty string for unsupported packages in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(UmdSync.core).to receive(:send).with(:supported_package?, 'vue').and_return(false)
      
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
      allow(UmdSync).to receive(:configuration).and_return(mock_config)
      allow(UmdSync.core).to receive(:send).with(:installed_packages).and_return([])
      
      # Should not crash
      expect { view_context.umd_partials }.not_to raise_error
    end

    it 'handles file system errors in umd_bundle_script' do
      allow(File).to receive(:read).and_raise(Errno::ENOENT)
      
      result = view_context.umd_bundle_script
      expect(result).to include('/umd_sync_bundle.js')
    end

    it 'handles JSON parsing errors gracefully' do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).and_return('invalid json {')
      
      result = view_context.umd_bundle_script
      expect(result).to include('/umd_sync_bundle.js')
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
      
      expect(result).to include('id="react-empty-component"')
      expect(result).to include('const props = {};')
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
      
      expect(result1).to include('id="react-component1"')
      expect(result2).to include('id="react-component2"')
    end
  end

  describe '#react_partials' do
    it 'renders React and ReactDOM partials when installed' do
      allow(UmdSync).to receive(:package_installed?).with('react').and_return(true)
      allow(UmdSync).to receive(:package_installed?).with('react-dom').and_return(true)
      
      result = view_context.react_partials
      
      expect(result).to include('React UMD content')
    end
  end

  describe '#react_component' do
    let(:props) { { userId: 123, theme: 'dark' } }
    
    it 'generates React component container and script' do
      result = view_context.react_component('MyComponent', props)
      
      expect(result).to include('id="react-my-component"')
      expect(result).to include('data-user-id="123"')
      expect(result).to include('data-theme="dark"')
      expect(result).to include('window.umd_sync.MyComponent')
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

  describe '#umd_bundle_script' do
    let(:manifest_path) { File.join(temp_dir, 'public', 'umd_sync_manifest.json') }
    
    before do
      FileUtils.mkdir_p(File.dirname(manifest_path))
    end
    
    it 'uses webpack manifest when available' do
      manifest = { 'umd_sync_bundle.js' => '/umd_sync_bundle.abc123.js' }
      File.write(manifest_path, JSON.generate(manifest))
      
      result = view_context.umd_bundle_script
      
      expect(result).to include('/umd_sync_bundle.abc123.js')
    end
    
    it 'uses umd_sync_bundle.js from manifest' do
      manifest = { 
        'umd_sync_bundle.js' => '/umd_sync_bundle.def456.js',
        'other_bundle.js' => '/other_bundle.abc123.js' 
      }
      File.write(manifest_path, JSON.generate(manifest))
      
      result = view_context.umd_bundle_script
      
      expect(result).to include('/umd_sync_bundle.def456.js')
    end
    
    it 'falls back to umd_sync_bundle.js when no manifest' do
      result = view_context.umd_bundle_script
      
      expect(result).to include('/umd_sync_bundle.js')
    end
    
    it 'handles invalid JSON gracefully' do
      File.write(manifest_path, 'invalid json{')
      
      result = view_context.umd_bundle_script
      
      expect(result).to include('/umd_sync_bundle.js')
    end
  end

  describe '#umd_sync' do
    it 'includes both partials and bundle script' do
      result = view_context.umd_sync
      
      expect(result).to be_html_safe
      expect(result).to_not be_empty
    end
  end

  describe '#umd_versions_debug' do
    it 'shows debug info in development' do
      # Mock the core.installed_packages method and supported_package? calls
      allow(UmdSync.core).to receive(:send).with(:installed_packages).and_return(['react', 'lodash'])
      allow(UmdSync.core).to receive(:send).with(:supported_package?, 'react').and_return(true)
      allow(UmdSync.core).to receive(:send).with(:supported_package?, 'lodash').and_return(true)
      allow(UmdSync).to receive(:version_for).with('react').and_return('18.3.1')
      allow(UmdSync).to receive(:version_for).with('lodash').and_return('4.17.21')
      
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
      allow(UmdSync.core).to receive(:send).with(:installed_packages).and_raise(StandardError.new('Test error'))
      
      result = view_context.umd_versions_debug
      
      expect(result).to include('UMD Error: Test error')
    end
  end
end 