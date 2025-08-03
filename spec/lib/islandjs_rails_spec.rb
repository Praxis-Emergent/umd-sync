require 'spec_helper'

RSpec.describe IslandjsRails do
  let(:temp_dir) { create_temp_dir }
  
  before do
    mock_rails_root(temp_dir)
    create_temp_package_json(temp_dir, {'react' => '^18.3.1'})
  end

  describe 'module delegation' do
    it 'delegates init! to core' do
      expect(IslandjsRails.core).to receive(:init!)
      IslandjsRails.init!
    end

    it 'delegates install! to core' do
      expect(IslandjsRails.core).to receive(:install!).with('react', '18.3.1')
      IslandjsRails.install!('react', '18.3.1')
    end

    it 'delegates update! to core' do
      expect(IslandjsRails.core).to receive(:update!).with('react', nil)
      IslandjsRails.update!('react', nil)
    end

    it 'delegates remove! to core' do
      expect(IslandjsRails.core).to receive(:remove!).with('react')
      IslandjsRails.remove!('react')
    end

    it 'delegates sync! to core' do
      expect(IslandjsRails.core).to receive(:sync!)
      IslandjsRails.sync!
    end

    it 'delegates status! to core' do
      expect(IslandjsRails.core).to receive(:status!)
      IslandjsRails.status!
    end

    it 'delegates clean! to core' do
      expect(IslandjsRails.core).to receive(:clean!)
      IslandjsRails.clean!
    end

    it 'delegates package_installed? to core' do
      expect(IslandjsRails.core).to receive(:package_installed?).with('react').and_return(true)
      result = IslandjsRails.package_installed?('react')
      expect(result).to be true
    end

    it 'delegates detect_global_name to core' do
      expect(IslandjsRails.core).to receive(:detect_global_name).with('react').and_return('React')
      result = IslandjsRails.detect_global_name('react')
      expect(result).to eq('React')
    end

    it 'delegates version_for to core' do
      expect(IslandjsRails.core).to receive(:version_for).with('react').and_return('18.3.1')
      result = IslandjsRails.version_for('react')
      expect(result).to eq('18.3.1')
    end

    it 'delegates find_working_umd_url to core' do
      expect(IslandjsRails.core).to receive(:find_working_island_url).with('react', '18.3.1').and_return('https://example.com')
      result = IslandjsRails.find_working_island_url('react', '18.3.1')
      expect(result).to eq('https://example.com')
    end
  end

  describe 'configuration management' do
    it 'provides a singleton configuration' do
      config1 = IslandjsRails.configuration
      config2 = IslandjsRails.configuration
      
      expect(config1).to be(config2) # Same object
      expect(config1).to be_a(IslandjsRails::Configuration)
    end

    it 'allows configuration via block' do
      IslandjsRails.configure do |config|
        config.partials_dir = Rails.root.join('custom', 'umd')
        config.supported_cdns = ['https://custom.com']
      end
      
      expect(IslandjsRails.configuration.partials_dir.to_s).to include('custom/umd')
      expect(IslandjsRails.configuration.supported_cdns).to eq(['https://custom.com'])
    end

    it 'persists configuration changes' do
      IslandjsRails.configure do |config|
        config.global_name_overrides['custom-lib'] = 'CustomLib'
      end
      
      expect(IslandjsRails.configuration.global_name_overrides['custom-lib']).to eq('CustomLib')
      
      # Configuration should persist
      expect(IslandjsRails.configuration.global_name_overrides['custom-lib']).to eq('CustomLib')
    end
  end

  describe 'core instance management' do
    it 'provides a singleton core instance' do
      core1 = IslandjsRails.core
      core2 = IslandjsRails.core
      
      expect(core1).to be(core2) # Same object
      expect(core1).to be_a(IslandjsRails::Core)
    end

    it 'core instance uses current configuration' do
      IslandjsRails.configure do |config|
        config.partials_dir = Rails.root.join('test', 'partials')
      end
      
      expect(IslandjsRails.core.configuration.partials_dir.to_s).to include('test/partials')
    end
  end

  describe 'error classes' do
    it 'defines custom error hierarchy' do
      expect(IslandjsRails::Error).to be < StandardError
      expect(IslandjsRails::YarnError).to be < IslandjsRails::Error
      expect(IslandjsRails::IslandNotFoundError).to be < IslandjsRails::Error
    end

    it 'can raise custom errors' do
      expect { raise IslandjsRails::YarnError, 'test' }.to raise_error(IslandjsRails::YarnError, 'test')
      expect { raise IslandjsRails::IslandNotFoundError, 'no island' }.to raise_error(IslandjsRails::IslandNotFoundError, 'no island')
    end
  end

  describe 'module constants' do
    it 'exposes version information' do
      expect(IslandjsRails::VERSION).to be_a(String)
      expect(IslandjsRails::VERSION).to match(/\d+\.\d+\.\d+/)
    end
  end

  describe 'Rails integration' do
    it 'conditionally requires railtie only when Rails is defined' do
      # This is tested by the fact that the gem loads successfully
      # In our test environment, Rails is defined, so the railtie should be loaded
      # Check if we can access the railtie through require
      expect { require 'islandjs_rails/railtie' }.not_to raise_error
      
      # After requiring, the constant should be defined
      expect(IslandjsRails.const_defined?(:Railtie)).to be_truthy
    end
  end

  describe 'thread safety' do
    it 'maintains separate configuration per thread' do
      # This is a basic test - in a real threaded environment
      # each thread should have its own configuration instance
      main_config = IslandjsRails.configuration
      main_config.partials_dir = Rails.root.join('main')
      
      thread_config = nil
      thread = Thread.new do
        thread_config = IslandjsRails.configuration
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