require_relative '../../spec_helper'
require 'islandjs_rails/configuration'

RSpec.describe IslandjsRails::Configuration do
  let(:temp_dir) { create_temp_dir }
  
  before do
    mock_rails_root(temp_dir)
  end

  describe '#initialize' do
    it 'sets default values' do
      config = described_class.new
      
      expect(config.package_json_path).to eq(Pathname.new(temp_dir).join('package.json'))
      expect(config.partials_dir).to eq(Pathname.new(temp_dir).join('app', 'views', 'shared', 'islands'))
      expect(config.webpack_config_path).to eq(Pathname.new(temp_dir).join('webpack.config.js'))
      expect(config.supported_cdns).to include('https://unpkg.com', 'https://cdn.jsdelivr.net/npm')
      expect(config.global_name_overrides).to include('react' => 'React')
    end
  end

  describe 'global name overrides' do
    it 'includes built-in mappings' do
      config = described_class.new
      
      expect(config.global_name_overrides['react']).to eq('React')
      expect(config.global_name_overrides['react-dom']).to eq('ReactDOM')
      expect(config.global_name_overrides['lodash']).to eq('_')
      expect(config.global_name_overrides['@solana/web3.js']).to eq('solanaWeb3')
    end

    it 'allows custom overrides' do
      config = described_class.new
      config.global_name_overrides['my-package'] = 'MyPackage'
      
      expect(config.global_name_overrides['my-package']).to eq('MyPackage')
    end
  end

  describe 'UMD path patterns' do
    it 'includes common patterns' do
      expect(IslandjsRails::UMD_PATH_PATTERNS).to include(
        'umd/{name}.min.js',
        'dist/{name}.min.js',
        'lib/{name}.js',
        '{name}.min.js'
      )
    end
  end

  describe 'CDN bases' do
    it 'includes major CDNs' do
      expect(IslandjsRails::CDN_BASES).to include(
        'https://unpkg.com',
        'https://cdn.jsdelivr.net/npm'
      )
    end
  end

  describe 'configuration modification' do
    it 'allows runtime configuration changes' do
      config = IslandjsRails::Configuration.new
      config.partials_dir = Rails.root.join('custom', 'partials')
      config.supported_cdns = ['https://custom-cdn.com']
      
      expect(config.partials_dir.to_s).to include('custom/partials')
      expect(config.supported_cdns).to eq(['https://custom-cdn.com'])
    end

    it 'allows adding custom global name overrides' do
      config = IslandjsRails::Configuration.new
      config.global_name_overrides['@custom/package'] = 'CustomPackage'
      
      expect(config.global_name_overrides['@custom/package']).to eq('CustomPackage')
      expect(config.global_name_overrides['react']).to eq('React') # Built-in still works
    end

    it 'preserves built-in overrides when modified' do
      config = IslandjsRails::Configuration.new
      original_count = config.global_name_overrides.size
      
      config.global_name_overrides['new-package'] = 'NewPackage'
      
      expect(config.global_name_overrides.size).to eq(original_count + 1)
      expect(config.global_name_overrides['react']).to eq('React')
    end
  end

  describe 'path handling' do
    it 'uses Pathname objects for paths' do
      config = IslandjsRails::Configuration.new
      
      expect(config.package_json_path).to be_a(Pathname)
      expect(config.partials_dir).to be_a(Pathname)
      expect(config.webpack_config_path).to be_a(Pathname)
    end

    it 'handles custom Rails root' do
      custom_root = Pathname.new('/custom/rails/app')
      allow(Rails).to receive(:root).and_return(custom_root)
      
      config = IslandjsRails::Configuration.new
      
      expect(config.package_json_path.to_s).to start_with('/custom/rails/app')
      expect(config.partials_dir.to_s).to include('/custom/rails/app/app/views/shared/islands')
    end
  end

  describe 'CDN configuration' do
    it 'provides multiple CDN options' do
      expect(IslandjsRails::CDN_BASES).to include('https://unpkg.com')
      expect(IslandjsRails::CDN_BASES).to include('https://cdn.jsdelivr.net/npm')
      expect(IslandjsRails::CDN_BASES.size).to be >= 2
    end

    it 'allows CDN configuration changes' do
      config = IslandjsRails::Configuration.new
      config.supported_cdns = ['https://custom1.com', 'https://custom2.com']
      
      expect(config.supported_cdns).to eq(['https://custom1.com', 'https://custom2.com'])
    end
  end

  describe 'constants validation' do
    it 'has comprehensive UMD path patterns' do
      expect(IslandjsRails::UMD_PATH_PATTERNS).to be_an(Array)
      expect(IslandjsRails::UMD_PATH_PATTERNS.size).to be > 10
      expect(IslandjsRails::UMD_PATH_PATTERNS).to include('umd/{name}.min.js')
      expect(IslandjsRails::UMD_PATH_PATTERNS).to include('dist/{name}.umd.min.js')
    end

    it 'has essential global name mappings' do
      overrides = IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES
      
      expect(overrides['react']).to eq('React')
      expect(overrides['react-dom']).to eq('ReactDOM')
      expect(overrides['lodash']).to eq('_')
      expect(overrides['jquery']).to eq('$')
    end

    it 'has scoped package mappings' do
      overrides = IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES
      
      expect(overrides['@solana/web3.js']).to eq('solanaWeb3')
    end
  end
end 