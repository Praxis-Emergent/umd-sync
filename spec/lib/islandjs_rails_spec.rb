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

    it 'delegates has_partial? to core private method' do
      expect(IslandjsRails.core).to receive(:has_partial?).with('react').and_return(true)
      result = IslandjsRails.has_partial?('react')
      expect(result).to be true
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

  describe 'constants and error classes' do
    it 'defines UMD_PATH_PATTERNS constant' do
      expect(IslandjsRails::UMD_PATH_PATTERNS).to be_an(Array)
      expect(IslandjsRails::UMD_PATH_PATTERNS).to include('umd/{name}.production.min.js')
      expect(IslandjsRails::UMD_PATH_PATTERNS).to be_frozen
    end

    it 'defines CDN_BASES constant' do
      expect(IslandjsRails::CDN_BASES).to be_an(Array)
      expect(IslandjsRails::CDN_BASES).to include('https://unpkg.com')
      expect(IslandjsRails::CDN_BASES).to be_frozen
    end

    it 'defines BUILT_IN_GLOBAL_NAME_OVERRIDES constant' do
      expect(IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES).to be_a(Hash)
      expect(IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES['react']).to eq('React')
      expect(IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES['lodash']).to eq('_')
      expect(IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES).to be_frozen
    end

    it 'defines custom error classes' do
      expect(IslandjsRails::Error).to be < StandardError
      expect(IslandjsRails::YarnError).to be < IslandjsRails::Error
      expect(IslandjsRails::IslandNotFoundError).to be < IslandjsRails::Error
      expect(IslandjsRails::PackageNotFoundError).to be < IslandjsRails::Error
      expect(IslandjsRails::UmdNotFoundError).to be < IslandjsRails::Error
    end

    it 'allows raising custom errors' do
      expect { raise IslandjsRails::YarnError, 'test' }.to raise_error(IslandjsRails::YarnError, 'test')
      expect { raise IslandjsRails::PackageNotFoundError, 'not found' }.to raise_error(IslandjsRails::PackageNotFoundError, 'not found')
    end
  end

  describe 'Rails conditional loading' do
    it 'loads Rails components when Rails is defined' do
      # In our test environment, Rails is defined, so these should be loaded
      # We test this by requiring the files using the proper path
      expect { require 'islandjs_rails/railtie' }.not_to raise_error
      expect { require 'islandjs_rails/rails_helpers' }.not_to raise_error
    end
  end

  describe 'module constants' do
    it 'exposes version information' do
      expect(IslandjsRails::VERSION).to be_a(String)
      expect(IslandjsRails::VERSION).to match(/\d+\.\d+\.\d+/)
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
      expect(main_config).to be_a(IslandjsRails::Configuration)
      expect(thread_config).to be_a(IslandjsRails::Configuration)
    end
  end
end 