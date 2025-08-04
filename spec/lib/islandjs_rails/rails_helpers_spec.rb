require_relative '../../spec_helper'

# Define Rails if not already defined for testing
unless defined?(Rails)
  module Rails
    def self.env
      @env ||= ActiveSupport::StringInquirer.new('test')
    end
    
    def self.root
      @root ||= Pathname.new('/test')
    end
  end
  
  # Create a minimal ActiveSupport::StringInquirer for testing
  module ActiveSupport
    class StringInquirer < String
      def method_missing(method_name, *args)
        method_name.to_s.chomp('?') == self
      end
    end
  end
end

# Now require the rails helpers
require_relative '../../../lib/islandjs_rails/rails_helpers'

RSpec.describe IslandjsRails::RailsHelpers do
  let(:test_instance) do
    Class.new do
      include IslandjsRails::RailsHelpers
      
      def content_tag(tag, content = "", options = {})
        attrs = options.map { |k, v| 
          if k == :data
            v.map { |dk, dv| "data-#{dk.to_s.gsub('_', '-')}=\"#{dv}\"" }.join(' ')
          else
            "#{k}=\"#{v}\""
          end
        }.join(' ')
        attrs = ' ' + attrs unless attrs.empty?
        "<#{tag}#{attrs}>#{content}</#{tag}>"
      end
      
      def render(options)
        if options[:partial]
          "<script>/* UMD partial */</script>"
          else
          ""
        end
      end
    end.new
  end

    before do
    allow(Rails).to receive(:env).and_return(double(development?: true, production?: false))
    allow(Rails).to receive(:root).and_return(Pathname.new('/test'))
    allow(SecureRandom).to receive(:hex).with(4).and_return('test123')
    allow(IslandjsRails).to receive(:has_partial?).and_return(true)
    allow(IslandjsRails).to receive(:status!).and_return("react: 18.3.1")
    allow(IslandjsRails).to receive(:configuration).and_return(
      double(partials_dir: Pathname.new('/test/partials'))
    )
    allow(Dir).to receive(:glob).and_return([])
    allow(File).to receive(:exist?).and_return(false)
        end

  describe '#react_component' do
    it 'generates secure React component with sessionStorage' do
      result = test_instance.react_component('HelloWorld', { message: 'Hello' })
      
      expect(result).to include('id="react_test123"')
      expect(result).to include('class="react-island"')
      expect(result).to include('data-component="HelloWorld"')
      expect(result).to include('IslandStateManager')
      expect(result).to include('sessionStorage')
      expect(result).to include('sanitizeState')
    end
    
    it 'removes sensitive props for security' do
      props = { message: 'Hello', password: 'secret123', api_token: 'token456' }
      result = test_instance.react_component('SecureComponent', props)
      
      # Should not include sensitive data values in script
      expect(result).not_to include('secret123')
      expect(result).not_to include('token456')
      expect(result).to include('Hello')
    end

    it 'uses external scripts in production' do
      allow(Rails).to receive(:env).and_return(double(development?: false, production?: true))
      
      result = test_instance.react_component('HelloWorld', {})
      
      expect(result).to include('src="/islands/mount/hello_world.js"')
      expect(result).to include('defer')
    end
  end

  describe '#vue_component' do
    it 'generates Vue component' do
      result = test_instance.vue_component('VueComponent', { message: 'Hello' })
      
      expect(result).to include('id="vue_test123"')
      expect(result).to include('class="vue-island"')
      expect(result).to include('Vue')
    end
  end

  describe '#island_component' do
    it 'delegates to react_component for React' do
      expect(test_instance).to receive(:react_component).with('Test', {}, {})
      test_instance.island_component('Test', 'react', {}, {})
    end

    it 'returns error for unsupported framework' do
      result = test_instance.island_component('Test', 'angular', {})
      expect(result).to include('Unsupported framework')
    end
  end

  describe '#island_debug' do
    it 'returns debug info in development' do
      result = test_instance.island_debug
      expect(result).to include('IslandJS Rails Debug')
    end

    it 'returns empty in production' do
      allow(Rails).to receive(:env).and_return(double(development?: false, production?: true))
      expect(test_instance.island_debug).to eq('')
    end
  end

  describe '#sanitize_component_props' do
    it 'removes sensitive keys' do
      props = { message: 'hello', password: 'secret999', api_token: 'token789' }
      sanitized = test_instance.send(:sanitize_component_props, props)
      
      expect(sanitized).to have_key(:message)
      expect(sanitized).not_to have_key(:password)
      expect(sanitized).not_to have_key(:api_token)
    end
  end

  describe 'Error handling' do
    describe 'island_debug' do
      it 'handles errors gracefully' do
        allow(IslandjsRails).to receive(:status!).and_raise(StandardError.new('Test error'))
        
        result = test_instance.island_debug
        expect(result).to include('IslandJS Debug Error: Test error')
        expect(result).to be_html_safe
    end
    
      it 'returns empty string in production' do
        allow(Rails).to receive(:env).and_return(double(development?: false))
        
        result = test_instance.island_debug
        expect(result).to eq('')
    end
    end

    describe 'umd_versions_debug' do
      it 'handles errors gracefully' do
        allow(Dir).to receive(:glob).and_raise(StandardError.new('Directory error'))
        
        result = test_instance.umd_versions_debug
        expect(result).to include('UMD Debug Error: Directory error')
        expect(result).to be_html_safe
    end
    
      it 'returns empty string in production' do
        allow(Rails).to receive(:env).and_return(double(development?: false))
        
        result = test_instance.umd_versions_debug
        expect(result).to eq('')
    end
  end

    describe 'umd_partial_for' do
      it 'handles render errors gracefully in development' do
        allow(IslandjsRails).to receive(:has_partial?).and_return(true)
        allow(test_instance).to receive(:render).and_raise(StandardError.new('Render error'))
      
        result = test_instance.umd_partial_for('test')
        expect(result).to include('Error rendering UMD partial for test: Render error')
        expect(result).to be_html_safe
    end
    
      it 'returns empty string for render errors in production' do
        allow(Rails).to receive(:env).and_return(double(development?: false, production?: true))
        allow(IslandjsRails).to receive(:has_partial?).and_return(true)
        allow(test_instance).to receive(:render).and_raise(StandardError.new('Render error'))
        
        result = test_instance.umd_partial_for('test')
        expect(result).to eq('')
    end
  end

    describe 'find_bundle_path' do
      it 'handles JSON parse errors gracefully' do
        manifest_path = Rails.root.join('public', 'islands_manifest.json')
        allow(File).to receive(:exist?).with(manifest_path).and_return(true)
        allow(File).to receive(:read).with(manifest_path).and_return('invalid json{')
        
        direct_bundle = Rails.root.join('public', 'islands_bundle.js')
        allow(File).to receive(:exist?).with(direct_bundle).and_return(true)
      
        result = test_instance.send(:find_bundle_path)
        expect(result).to eq('/islands_bundle.js')
    end
    
      it 'returns nil when no bundle files exist' do
        manifest_path = Rails.root.join('public', 'islands_manifest.json')
        direct_bundle = Rails.root.join('public', 'islands_bundle.js')
        
        allow(File).to receive(:exist?).with(manifest_path).and_return(false)
        allow(File).to receive(:exist?).with(direct_bundle).and_return(false)
      
        result = test_instance.send(:find_bundle_path)
      expect(result).to be_nil
    end
    end
  end
end 
