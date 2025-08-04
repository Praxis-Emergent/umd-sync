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
    
    def self.application
      @application ||= double('Application', 
        config: double('Config', 
          asset_host: nil,
          content_security_policy: nil,
          assets: double('Assets', precompile: [])
        ),
        importmap: nil
      )
    end
  end
  
  module ActiveSupport
    class StringInquirer < String
      def method_missing(method_name, *args)
        method_name.to_s.chomp('?') == self
      end
    end
  end
end

require_relative '../../../lib/islandjs_rails/rails_helpers'

RSpec.describe 'Rails 8 + Turbo Compatibility' do
  let(:test_instance) do
    Class.new do
      include IslandjsRails::RailsHelpers
      
      def content_tag(tag, content = "", options = {})
        nonce = options.delete(:nonce)
        attrs = options.map { |k, v| 
          if k == :data
            v.map { |dk, dv| "data-#{dk.to_s.gsub('_', '-')}=\"#{dv}\"" }.join(' ')
          else
            "#{k}=\"#{v}\""
          end
        }.join(' ')
        attrs = ' ' + attrs unless attrs.empty?
        nonce_attr = nonce ? " nonce=\"#{nonce}\"" : ""
        "<#{tag}#{attrs}#{nonce_attr}>#{content}</#{tag}>"
      end
      
      def content_security_policy_nonce
        'test-nonce-123'
      end
      
      def asset_url(path)
        "https://cdn.example.com#{path}"
      end
    end.new
  end

  before do
    allow(Rails).to receive(:env).and_return(double(development?: true, production?: false))
    allow(Rails).to receive(:root).and_return(Pathname.new('/test'))
    allow(SecureRandom).to receive(:hex).with(4).and_return('test123')
  end

  describe 'CSP Compliance' do
    it 'includes CSP nonce for inline scripts in development' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('nonce="test-nonce-123"')
    end
    
    it 'uses external scripts with asset_url in production with import maps' do
      allow(Rails).to receive(:env).and_return(double(development?: false, production?: true))
      allow(test_instance).to receive(:import_maps_enabled?).and_return(true)
      
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('src="https://cdn.example.com/islands/mount/test_component.js"')
      expect(result).to include('defer')
      expect(result).not_to include('nonce=')
    end
  end

  describe 'Complete Turbo Event Handling' do
    it 'includes all required Turbo events' do
      result = test_instance.react_component('TestComponent', {})
      
      # Core Turbo Drive events
      expect(result).to include("addEventListener('turbo:load'")
      expect(result).to include("addEventListener('turbo:before-cache'")
      expect(result).to include("addEventListener('turbo:render'")
      expect(result).to include("addEventListener('turbo:before-render'")
      
      # Additional Turbo events for complete compatibility
      expect(result).to include("addEventListener('turbo:before-visit'")
      expect(result).to include("addEventListener('turbo:visit'")
      expect(result).to include("addEventListener('turbo:frame-load'")
      
      # Legacy Turbolinks
      expect(result).to include("addEventListener('turbolinks:load'")
      expect(result).to include("addEventListener('turbolinks:before-cache'")
    end
    
    it 'includes specific event handlers for each event type' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('handleBeforeVisitTestComponent')
      expect(result).to include('handleVisitTestComponent')
      expect(result).to include('handleFrameLoadTestComponent')
    end
  end

  describe 'Memory Management' do
    it 'includes component registry for cleanup' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('components: new Map()')
      expect(result).to include("window.IslandjsRails.components.set('react_test123'")
      expect(result).to include("window.IslandjsRails.components.delete('react_test123')")
    end
    
    it 'includes sessionStorage size management' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('getStorageSize')
      expect(result).to include('cleanupOldStates')
      expect(result).to include('handleStorageError')
      expect(result).to include('QuotaExceededError')
    end
    
    it 'includes proper error handling' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('try {')
      expect(result).to include('} catch (error) {')
      expect(result).to include('Component failed to load')
    end
  end

  describe 'Form State Preservation' do
    it 'includes FormStateManager' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('const FormStateManager')
      expect(result).to include('FormStateManager.preserve')
      expect(result).to include('FormStateManager.restore')
      expect(result).to include("querySelectorAll('form')")
    end
    
    it 'preserves and restores form state on navigation' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('new FormData(form)')
      expect(result).to include('window.IslandjsRails.formStates')
      expect(result).to include("input.value = value")
    end
  end

  describe 'Focus Management' do
    it 'includes FocusManager for accessibility' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('const FocusManager')
      expect(result).to include('FocusManager.preserve')
      expect(result).to include('FocusManager.restore')
      expect(result).to include('document.activeElement')
      expect(result).to include('requestAnimationFrame')
    end
    
    it 'restores focus after turbo:load' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include("addEventListener('turbo:load', FocusManager.restore)")
    end
  end

  describe 'Import Maps Integration' do
    it 'detects import maps and uses external scripts' do
      allow(test_instance).to receive(:import_maps_enabled?).and_return(true)
      
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('src=')
      expect(result).to include('defer')
    end
    
    it 'handles import maps gracefully when not available' do
      allow(test_instance).to receive(:import_maps_enabled?).and_return(false)
      
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('<script')
    end
  end

  describe 'Asset Path Resolution' do
    it 'uses asset_url when available' do
      result = test_instance.react_component('TestComponent', {})
      
      # In production mode, it should use the asset_url helper
      allow(Rails).to receive(:env).and_return(double(development?: false, production?: true))
      allow(test_instance).to receive(:import_maps_enabled?).and_return(true)
      
      result = test_instance.react_component('TestComponent', {})
      expect(result).to include('https://cdn.example.com')
    end
  end

  describe 'State Sanitization' do
    it 'includes enhanced state sanitization with size limits' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('sanitizeState')
      expect(result).to include('isSafeValue')
      expect(result).to include('isSensitive')
      expect(result).to include("keyStr.includes(s)")
    end
  end

  describe 'Progressive Enhancement' do
    it 'includes fallback for component mount failures' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('Component failed to load')
      expect(result).to include('console.error')
      expect(result).to include('container.innerHTML')
    end
    
    it 'checks for React/ReactDOM availability' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include("typeof React === 'undefined'")
      expect(result).to include("typeof ReactDOM === 'undefined'")
      expect(result).to include('React or ReactDOM not loaded')
    end
  end

  describe 'Rails 8 Compatibility Markers' do
    it 'includes Rails 8 + Turbo compatible comment' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('Rails 8 + Turbo Compatible State Manager')
    end
    
    it 'initializes global IslandjsRails object with required maps' do
      result = test_instance.react_component('TestComponent', {})
      
      expect(result).to include('window.IslandjsRails = {')
      expect(result).to include('components: new Map()')
      expect(result).to include('formStates: new Map()')
      expect(result).to include('scrollPositions: new Map()')
    end
  end
end 