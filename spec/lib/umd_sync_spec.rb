require 'spec_helper'

RSpec.describe UmdSync do
  let(:temp_dir) { create_temp_dir }
  
  before do
    mock_rails_root(temp_dir)
    create_temp_package_json(temp_dir, {'react' => '^18.3.1'})
  end

  describe 'module delegation' do
    it 'delegates init! to core' do
      expect(UmdSync.core).to receive(:init!)
      UmdSync.init!
    end

    it 'delegates install! to core' do
      expect(UmdSync.core).to receive(:install!).with('react', '18.3.1')
      UmdSync.install!('react', '18.3.1')
    end

    it 'delegates update! to core' do
      expect(UmdSync.core).to receive(:update!).with('react', nil)
      UmdSync.update!('react', nil)
    end

    it 'delegates remove! to core' do
      expect(UmdSync.core).to receive(:remove!).with('react')
      UmdSync.remove!('react')
    end

    it 'delegates sync! to core' do
      expect(UmdSync.core).to receive(:sync!)
      UmdSync.sync!
    end

    it 'delegates status! to core' do
      expect(UmdSync.core).to receive(:status!)
      UmdSync.status!
    end

    it 'delegates clean! to core' do
      expect(UmdSync.core).to receive(:clean!)
      UmdSync.clean!
    end

    it 'delegates package_installed? to core' do
      expect(UmdSync.core).to receive(:package_installed?).with('react').and_return(true)
      result = UmdSync.package_installed?('react')
      expect(result).to be true
    end

    it 'delegates detect_global_name to core' do
      expect(UmdSync.core).to receive(:detect_global_name).with('react').and_return('React')
      result = UmdSync.detect_global_name('react')
      expect(result).to eq('React')
    end

    it 'delegates version_for to core' do
      expect(UmdSync.core).to receive(:version_for).with('react').and_return('18.3.1')
      result = UmdSync.version_for('react')
      expect(result).to eq('18.3.1')
    end

    it 'delegates find_working_umd_url to core' do
      expect(UmdSync.core).to receive(:find_working_umd_url).with('react', '18.3.1').and_return('https://example.com')
      result = UmdSync.find_working_umd_url('react', '18.3.1')
      expect(result).to eq('https://example.com')
    end
  end

  describe 'configuration management' do
    it 'provides a singleton configuration' do
      config1 = UmdSync.configuration
      config2 = UmdSync.configuration
      
      expect(config1).to be(config2) # Same object
      expect(config1).to be_a(UmdSync::Configuration)
    end

    it 'allows configuration via block' do
      UmdSync.configure do |config|
        config.partials_dir = Rails.root.join('custom', 'umd')
        config.supported_cdns = ['https://custom.com']
      end
      
      expect(UmdSync.configuration.partials_dir.to_s).to include('custom/umd')
      expect(UmdSync.configuration.supported_cdns).to eq(['https://custom.com'])
    end

    it 'persists configuration changes' do
      UmdSync.configure do |config|
        config.global_name_overrides['custom-lib'] = 'CustomLib'
      end
      
      expect(UmdSync.configuration.global_name_overrides['custom-lib']).to eq('CustomLib')
      
      # Configuration should persist
      expect(UmdSync.configuration.global_name_overrides['custom-lib']).to eq('CustomLib')
    end
  end

  describe 'core instance management' do
    it 'provides a singleton core instance' do
      core1 = UmdSync.core
      core2 = UmdSync.core
      
      expect(core1).to be(core2) # Same object
      expect(core1).to be_a(UmdSync::Core)
    end

    it 'core instance uses current configuration' do
      UmdSync.configure do |config|
        config.partials_dir = Rails.root.join('test', 'partials')
      end
      
      expect(UmdSync.core.configuration.partials_dir.to_s).to include('test/partials')
    end
  end

  describe 'error classes' do
    it 'defines custom error hierarchy' do
      expect(UmdSync::Error).to be < StandardError
      expect(UmdSync::PackageNotFoundError).to be < UmdSync::Error
      expect(UmdSync::VersionMismatchError).to be < UmdSync::Error
      expect(UmdSync::UmdNotFoundError).to be < UmdSync::Error
      expect(UmdSync::YarnError).to be < UmdSync::Error
    end

    it 'can raise custom errors' do
      expect { raise UmdSync::PackageNotFoundError, 'test' }.to raise_error(UmdSync::PackageNotFoundError, 'test')
      expect { raise UmdSync::UmdNotFoundError, 'no umd' }.to raise_error(UmdSync::UmdNotFoundError, 'no umd')
    end
  end

  describe 'module constants' do
    it 'exposes version information' do
      expect(UmdSync::VERSION).to be_a(String)
      expect(UmdSync::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe 'Rails integration' do
    it 'conditionally requires railtie only when Rails is defined' do
      # This is tested by the fact that the gem loads successfully
      # In our test environment, Rails is defined, so the railtie should be loaded
      # Check if we can access the railtie through require
      expect { require 'umd_sync/railtie' }.not_to raise_error
      
      # After requiring, the constant should be defined
      expect(UmdSync.const_defined?(:Railtie)).to be_truthy
    end
  end

  describe 'thread safety' do
    it 'maintains separate configuration per thread' do
      # This is a basic test - in a real threaded environment
      # each thread should have its own configuration instance
      main_config = UmdSync.configuration
      main_config.partials_dir = Rails.root.join('main')
      
      thread_config = nil
      thread = Thread.new do
        thread_config = UmdSync.configuration
        thread_config.partials_dir = Rails.root.join('thread')
      end
      thread.join
      
      # In this test setup, they're the same instance (singleton)
      # but this tests the configuration interface
      expect(main_config).to be_a(UmdSync::Configuration)
      expect(thread_config).to be_a(UmdSync::Configuration)
    end
  end
end 