require 'spec_helper'

RSpec.describe 'Additional Coverage Tests' do
  let(:core) { IslandjsRails.core }
  
  before do
    allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
  end

  describe 'CLI and Tasks coverage' do
    describe IslandjsRails::CLI do
      let(:cli) { described_class.new }

      describe '#version' do
        it 'shows version information' do
          expect { cli.version }.to output(/IslandjsRails #{IslandjsRails::VERSION}/).to_stdout
        end
      end

      describe '#config' do
        it 'shows configuration information' do
          expect { cli.config }.to output(/IslandjsRails Configuration/).to_stdout
        end
      end
    end
  end

  describe 'Core method edge cases' do
    before do
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/test_app/package.json').and_return(true)
      allow(File).to receive(:read).with('/tmp/test_app/package.json').and_return('{"dependencies": {"react": "^18.0.0"}}')
    end

    describe '#detect_global_name' do
      it 'uses built-in overrides for known packages' do
        result = core.send(:detect_global_name, 'react')
        expect(result).to eq('React')
      end

      it 'uses built-in overrides for scoped packages' do
        result = core.send(:detect_global_name, '@solana/web3.js')
        expect(result).to eq('solanaWeb3')
      end

      it 'converts kebab-case to camelCase for unknown packages' do
        result = core.send(:detect_global_name, 'my-custom-package')
        expect(result).to eq('myCustomPackage')
      end

      it 'handles packages with multiple hyphens' do
        result = core.send(:detect_global_name, 'very-long-package-name')
        expect(result).to eq('veryLongPackageName')
      end

      it 'handles scoped packages without built-in mapping' do
        result = core.send(:detect_global_name, '@company/custom-lib')
        expect(result).to eq('customLib')
      end
    end

    describe '#find_working_umd_url' do
      it 'returns nil values when no URL is accessible' do
        allow(core).to receive(:url_accessible?).and_return(false)
        
        url, global_name = core.send(:find_working_umd_url, 'nonexistent-package', '1.0.0')
        expect(url).to be_nil
        expect(global_name).to be_nil
      end

      it 'handles packages with fixed filename patterns' do
        allow(core).to receive(:url_accessible?).and_return(true)
        allow(core).to receive(:detect_global_name).and_return('SolanaWeb3')
        
        url, global_name = core.send(:find_working_umd_url, '@solana/web3.js', '1.0.0')
        expect(url).to be_a(String)
        expect(global_name).to eq('SolanaWeb3')
      end
    end

    describe '#generate_partial_content' do
      it 'generates base64 encoded partial content' do
        content = core.send(:generate_partial_content, 'react', 'console.log("test");', 'React')
        expect(content).to include('React UMD Library')
        expect(content).to include('Global: React')
        expect(content).to include('atob(')
      end

      it 'handles packages with special characters in names' do
        content = core.send(:generate_partial_content, '@solana/web3.js', 'console.log("test");', 'solanaWeb3')
        expect(content).to include('solanaWeb3 UMD Library')
        expect(content).to include('Global: solanaWeb3')
      end
    end

    describe '#supported_package?' do
      it 'returns true for packages with dependencies' do
        allow(File).to receive(:read).with('/tmp/test_app/package.json').and_return('{"dependencies": {"react": "^18.0.0"}}')
        result = core.send(:supported_package?, 'react')
        expect(result).to be true
      end

      it 'returns true for all packages (current implementation)' do
        result = core.send(:supported_package?, 'any-package')
        expect(result).to be true
      end
    end


  end

  describe 'Configuration edge cases' do
    let(:config) { IslandjsRails::Configuration.new }

    describe 'path methods' do
      it 'handles complex package names in vendor_file_path' do
        result = config.vendor_file_path('@babel/preset-env', '7.23.0')
        expect(result.to_s).to include('_babel_preset_env-7.23.0.min.js')
      end

      it 'generates unique combined vendor paths' do
        result1 = config.combined_vendor_path('abc123')
        result2 = config.combined_vendor_path('def456')
        expect(result1.to_s).to include('abc123')
        expect(result2.to_s).to include('def456')
        expect(result1).not_to eq(result2)
      end
    end
  end

  describe 'Constants and module-level methods' do
    it 'has UMD_PATH_PATTERNS constant' do
      expect(IslandjsRails::UMD_PATH_PATTERNS).to be_an(Array)
      expect(IslandjsRails::UMD_PATH_PATTERNS).to include('umd/{name}.min.js')
      expect(IslandjsRails::UMD_PATH_PATTERNS).to include('lib/index.iife.min.js')
    end

    it 'has CDN_BASES constant' do
      expect(IslandjsRails::CDN_BASES).to be_an(Array)
      expect(IslandjsRails::CDN_BASES).to include('https://unpkg.com')
    end

    it 'has BUILT_IN_GLOBAL_NAME_OVERRIDES constant' do
      expect(IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES).to be_a(Hash)
      expect(IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES['react']).to eq('React')
      expect(IslandjsRails::BUILT_IN_GLOBAL_NAME_OVERRIDES['@solana/web3.js']).to eq('solanaWeb3')
    end

    describe 'module methods' do
      describe '.core' do
        it 'returns a Core instance' do
          expect(IslandjsRails.core).to be_a(IslandjsRails::Core)
        end

        it 'memoizes the core instance' do
          core1 = IslandjsRails.core
          core2 = IslandjsRails.core
          expect(core1).to be(core2)
        end
      end

      describe '.vendor_manager' do
        it 'returns a VendorManager instance' do
          expect(IslandjsRails.vendor_manager).to be_a(IslandjsRails::VendorManager)
        end
      end

      describe '.version_for' do
        before do
          package_json_path = Pathname.new('/tmp/test_app/package.json')
          allow(File).to receive(:exist?).with(package_json_path).and_return(true)
          allow(File).to receive(:read).with(package_json_path).and_return('{"dependencies": {"react": "^18.2.0"}}')
        end

        it 'returns version for installed package' do
          result = IslandjsRails.version_for('react')
          expect(result).to eq('18.2.0')
        end

        it 'returns nil for non-installed package' do
          result = IslandjsRails.version_for('nonexistent')
          expect(result).to be_nil
        end
      end
    end
  end

  describe 'Error classes' do
    it 'defines custom error classes' do
      expect(IslandjsRails::Error).to be < StandardError
      expect(IslandjsRails::PackageNotFoundError).to be < IslandjsRails::Error
      expect(IslandjsRails::UmdNotFoundError).to be < IslandjsRails::Error
      expect(IslandjsRails::YarnError).to be < IslandjsRails::Error
    end
  end
end
