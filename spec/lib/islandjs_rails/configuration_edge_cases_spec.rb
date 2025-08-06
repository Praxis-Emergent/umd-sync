require 'spec_helper'

RSpec.describe IslandjsRails::Configuration do
  let(:configuration) { described_class.new }

  before do
    allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
  end

  describe 'vendor file helper methods' do
    describe '#vendor_file_path' do
      it 'handles scoped package names' do
        result = configuration.vendor_file_path('@solana/web3.js', '1.0.0')
        expect(result.to_s).to include('_solana_web3.js-1.0.0.min.js')
      end

      it 'handles packages with hyphens' do
        result = configuration.vendor_file_path('react-dom', '18.0.0')
        expect(result.to_s).to include('react_dom-18.0.0.min.js')
      end

      it 'handles packages with forward slashes' do
        result = configuration.vendor_file_path('namespace/package', '2.0.0')
        expect(result.to_s).to include('namespace_package-2.0.0.min.js')
      end
    end

    describe '#combined_vendor_path' do
      it 'generates path with hash' do
        result = configuration.combined_vendor_path('abc123')
        expect(result.to_s).to include('islands-vendor-abc123.js')
      end
    end

    describe '#vendor_manifest_path' do
      it 'returns manifest path in vendor directory' do
        result = configuration.vendor_manifest_path
        expect(result.to_s).to include('manifest.json')
      end
    end

    describe '#vendor_partial_path' do
      it 'returns partial path in partials directory' do
        result = configuration.vendor_partial_path
        expect(result.to_s).to include('_vendor_umd.html.erb')
      end
    end
  end

  describe 'configuration attributes' do
    it 'has default package_json_path' do
      expect(configuration.package_json_path.to_s).to include('package.json')
    end

    it 'has default partials_dir' do
      expect(configuration.partials_dir.to_s).to include('app/views/shared/islands')
    end

    it 'has default webpack_config_path' do
      expect(configuration.webpack_config_path.to_s).to include('webpack.config.js')
    end

    it 'has default vendor_script_mode' do
      expect(configuration.vendor_script_mode).to eq(:external_split)
    end

    it 'has default vendor_order' do
      expect(configuration.vendor_order).to eq(%w[react react-dom])
    end

    it 'has default supported_cdns' do
      expect(configuration.supported_cdns).to include('https://unpkg.com')
      expect(configuration.supported_cdns).to include('https://cdn.jsdelivr.net/npm')
    end

    it 'allows modification of attributes' do
      configuration.vendor_script_mode = :external_combined
      expect(configuration.vendor_script_mode).to eq(:external_combined)
    end
  end

  describe 'constants' do
    it 'has SCOPED_PACKAGE_MAPPINGS' do
      expect(IslandjsRails::Configuration::SCOPED_PACKAGE_MAPPINGS).to be_a(Hash)
      expect(IslandjsRails::Configuration::SCOPED_PACKAGE_MAPPINGS).to have_key('@solana/web3.js')
    end


  end
end
