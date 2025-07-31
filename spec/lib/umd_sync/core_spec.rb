require 'spec_helper'

RSpec.describe UmdSync::Core do
  let(:temp_dir) { create_temp_dir }
  let(:core) { described_class.new }
  
  before do
    mock_rails_root(temp_dir)
    create_temp_package_json(temp_dir, {
      'react' => '^18.3.1',
      'react-dom' => '^18.3.1',
      'lodash' => '^4.17.21'
    })
  end

  describe '#package_installed?' do
    it 'returns true for installed packages' do
      expect(core.package_installed?('react')).to be true
      expect(core.package_installed?('lodash')).to be true
    end

    it 'returns false for non-installed packages' do
      expect(core.package_installed?('vue')).to be false
    end

    it 'handles missing package.json gracefully' do
      File.delete(File.join(temp_dir, 'package.json'))
      expect(core.package_installed?('react')).to be false
    end
  end

  describe '#version_for' do
    it 'returns cleaned version for installed packages' do
      expect(core.version_for('react')).to eq('18.3.1')
      expect(core.version_for('lodash')).to eq('4.17.21')
    end

    it 'returns nil for non-installed packages' do
      expect(core.version_for('vue')).to be nil
    end

    it 'handles complex version strings' do
      create_temp_package_json(temp_dir, { 'test-package' => '~1.2.3' })
      expect(core.version_for('test-package')).to eq('1.2.3')
    end
  end

  describe '#detect_global_name' do
    it 'uses configured overrides first' do
      expect(core.detect_global_name('react')).to eq('React')
      expect(core.detect_global_name('react-dom')).to eq('ReactDOM')
      expect(core.detect_global_name('lodash')).to eq('_')
    end

    it 'converts kebab-case to camelCase for unknown packages' do
      expect(core.detect_global_name('my-awesome-package')).to eq('myAwesomePackage')
      expect(core.detect_global_name('single')).to eq('single')
    end

    it 'handles scoped packages' do
      expect(core.detect_global_name('@my/package')).to eq('package')
      expect(core.detect_global_name('@scope/multi-word')).to eq('multiWord')
    end
  end

  describe '#find_working_umd_url', :vcr do
    it 'finds working UMD URL for React', vcr: { cassette_name: 'react_umd_search' } do
      url, global_name = core.find_working_umd_url('react', '18.3.1')
      
      expect(url).to include('react@18.3.1')
      expect(url).to include('.min.js')
      expect(global_name).to eq('React')
    end

    it 'returns nil for non-existent packages', vcr: { cassette_name: 'nonexistent_package' } do
      url, global_name = core.find_working_umd_url('non-existent-package-xyz', '1.0.0')
      
      expect(url).to be_nil
      expect(global_name).to be_nil
    end
  end

  describe '#download_umd_content', :vcr do
    it 'downloads UMD content successfully', vcr: { cassette_name: 'download_react_umd' } do
      url = 'https://unpkg.com/react@18.3.1/umd/react.production.min.js'
      content = core.download_umd_content(url)
      
      expect(content).to be_a(String)
      expect(content).to include('React')
      expect(content.length).to be > 1000
    end

    it 'raises error for 404 URLs', vcr: { cassette_name: 'download_404_url' } do
      url = 'https://unpkg.com/non-existent@1.0.0/umd/not-found.js'
      
      expect {
        core.download_umd_content(url)
      }.to raise_error(UmdSync::Error, /Failed to download UMD/)
    end
  end

  describe '#create_partial_file' do
    let(:partials_dir) { File.join(temp_dir, 'app', 'views', 'shared', 'umd') }
    
    it 'creates partial file with UMD content' do
      umd_content = 'console.log("React UMD");'
      core.create_partial_file('react', umd_content, 'React')
      
      partial_path = File.join(partials_dir, '_react.html.erb')
      expect(File.exist?(partial_path)).to be true
      
      content = File.read(partial_path)
      expect(content).to include('React UMD Library')
      expect(content).to include('Global: React')
      expect(content).to include('atob(') # Base64 decoding
      expect(content).to include('createElement') # Dynamic script injection
    end

    it 'creates directory if it does not exist' do
      expect(Dir.exist?(partials_dir)).to be false
      
      core.create_partial_file('lodash', 'console.log("lodash");', '_')
      
      expect(Dir.exist?(partials_dir)).to be true
    end

    it 'handles special characters in package names' do
      core.create_partial_file('@solana/web3.js', 'console.log("solana");', 'solanaWeb3')
      
      # The @ and / get replaced with _ in the safe_name conversion
      # Note: .js extension is preserved in the filename
      partial_path = File.join(partials_dir, '__solana_web3.js.html.erb')
      expect(File.exist?(partial_path)).to be true
    end
  end

  describe '#update_webpack_externals' do
    let(:webpack_path) { File.join(temp_dir, 'webpack.config.js') }
    
    before do
      create_temp_webpack_config(temp_dir)
      # Create some partials to simulate installed packages
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'umd')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
      File.write(File.join(partials_dir, '_lodash.html.erb'), '<script>lodash</script>')
    end

    it 'updates webpack externals with installed packages' do
      core.update_webpack_externals
      
      webpack_content = File.read(webpack_path)
      expect(webpack_content).to include('"react": "React"')
      expect(webpack_content).to include('"lodash": "_"')
      expect(webpack_content).to include('UmdSync managed externals')
    end

    it 'preserves other webpack configuration' do
      original_content = File.read(webpack_path)
      core.update_webpack_externals
      
      webpack_content = File.read(webpack_path)
      expect(webpack_content).to include('module.exports')
    end
  end

  describe '#init!' do
    it 'creates necessary directories' do
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'umd')
      expect(Dir.exist?(partials_dir)).to be false
      
      expect { core.init! }.to output(/Initializing UmdSync/).to_stdout
      
      expect(Dir.exist?(partials_dir)).to be true
    end

    it 'generates webpack config if missing' do
      webpack_path = File.join(temp_dir, 'webpack.config.js')
      File.delete(webpack_path) if File.exist?(webpack_path)
      
      expect { core.init! }.to output(/Generated webpack.config.js/).to_stdout
      
      expect(File.exist?(webpack_path)).to be true
      content = File.read(webpack_path)
      expect(content).to include('umd_sync_react')
    end
  end

  describe '#status!' do
    before do
      # Create some partials
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'umd')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
    end

    it 'shows status of packages' do
      expect { core.status! }.to output(/UmdSync Status/).to_stdout
      expect { core.status! }.to output(/✅ react@18.3.1/).to_stdout
      expect { core.status! }.to output(/❌ lodash@4.17.21/).to_stdout
    end
  end

  describe '#clean!' do
    let(:partials_dir) { File.join(temp_dir, 'app', 'views', 'shared', 'umd') }
    
    before do
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
      File.write(File.join(partials_dir, '_lodash.html.erb'), '<script>lodash</script>')
      create_temp_webpack_config(temp_dir)
    end

    it 'removes all partial files' do
      expect(Dir.glob(File.join(partials_dir, '*.erb')).length).to eq(2)
      
      expect { core.clean! }.to output(/Cleaning UMD partials/).to_stdout
      
      expect(Dir.glob(File.join(partials_dir, '*.erb')).length).to eq(0)
    end

    it 'resets webpack externals' do
      core.update_webpack_externals # Add some externals first
      webpack_content_before = File.read(File.join(temp_dir, 'webpack.config.js'))
      expect(webpack_content_before).to include('"react": "React"')
      
      core.clean!
      
      webpack_content_after = File.read(File.join(temp_dir, 'webpack.config.js'))
      expect(webpack_content_after).not_to include('"react": "React"')
      expect(webpack_content_after).to include('UmdSync managed externals')
    end
  end

  describe '#remove!' do
    before do
      create_temp_package_json(temp_dir, {'react' => '^18.3.1'})
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'umd')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
    end

    it 'removes an installed package' do
      # Mock the yarn remove command
      allow(Open3).to receive(:capture3).with('yarn remove react', chdir: Rails.root)
                                        .and_return(['', '', double(success?: true)])
      
      expect { core.remove!('react') }.to output(/Successfully removed react/).to_stdout
    end

    it 'raises error for non-installed package' do
      expect { core.remove!('vue') }.to raise_error(UmdSync::PackageNotFoundError)
    end

    it 'handles yarn command failures' do
      allow(Open3).to receive(:capture3).with('yarn remove react', chdir: Rails.root)
                                        .and_return(['', 'Error removing', double(success?: false)])
      
      expect { core.remove!('react') }.to raise_error(UmdSync::YarnError, /Failed to remove react/)
    end

    it 'removes partial file and updates webpack externals' do
      partial_path = File.join(temp_dir, 'app', 'views', 'shared', 'umd', '_react.html.erb')
      expect(File.exist?(partial_path)).to be true
      
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
      allow(core).to receive(:update_webpack_externals)
      
      core.remove!('react')
      
      expect(File.exist?(partial_path)).to be false
      expect(core).to have_received(:update_webpack_externals)
    end
  end

  describe '#sync!' do
    before do
      create_temp_package_json(temp_dir, {
        'react' => '^18.3.1',
        'lodash' => '^4.17.21',
        'vue' => '^3.0.0'
      })
    end

    it 'syncs all supported packages', vcr: { cassette_name: 'sync_all_packages' } do
      # Use the actual sync! method but mock the network calls
      expect { core.sync! }.to output(/Syncing all UMD packages/).to_stdout
      
      # Verify that partials were created (indirect verification)
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'umd')
      expect(Dir.glob(File.join(partials_dir, '*.erb')).size).to be > 0
    end

    it 'processes packages during sync' do
      # Simple test that sync! runs without error and processes packages
      expect { core.sync! }.to output(/Syncing all UMD packages/).to_stdout
      expect { core.sync! }.to output(/Processing/).to_stdout
    end

    it 'handles empty package.json' do
      create_temp_package_json(temp_dir, {})
      
      expect { core.sync! }.to output(/Syncing all UMD packages/).to_stdout
    end
  end

  describe 'yarn integration methods' do
    describe '#add_package_via_yarn' do
      it 'adds package without version' do
        allow(Open3).to receive(:capture3).with('yarn add react', chdir: Rails.root)
                                          .and_return(['', '', double(success?: true)])
        
        expect { core.send(:add_package_via_yarn, 'react') }.to output(/Added to package.json: react/).to_stdout
      end

      it 'adds package with specific version' do
        allow(Open3).to receive(:capture3).with('yarn add react@18.3.1', chdir: Rails.root)
                                          .and_return(['', '', double(success?: true)])
        
        expect { core.send(:add_package_via_yarn, 'react', '18.3.1') }.to output(/Added to package.json: react@18.3.1/).to_stdout
      end

      it 'raises YarnError on failure' do
        allow(Open3).to receive(:capture3).with('yarn add react', chdir: Rails.root)
                                          .and_return(['', 'Network error', double(success?: false)])
        
        expect { core.send(:add_package_via_yarn, 'react') }.to raise_error(UmdSync::YarnError, /Failed to add react/)
      end

      it 'resets cached package.json' do
        allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
        
        core.instance_variable_set(:@package_json, {'old' => 'data'})
        core.send(:add_package_via_yarn, 'react')
        
        expect(core.instance_variable_get(:@package_json)).to be_nil
      end
    end

    describe '#yarn_update!' do
      it 'updates package to specific version using add' do
        allow(core).to receive(:add_package_via_yarn)
        
        core.send(:yarn_update!, 'react', '18.3.1')
        
        expect(core).to have_received(:add_package_via_yarn).with('react', '18.3.1')
      end

      it 'upgrades package without version' do
        allow(Open3).to receive(:capture3).with('yarn upgrade react', chdir: Rails.root)
                                          .and_return(['', '', double(success?: true)])
        
        expect { core.send(:yarn_update!, 'react') }.to output(/Updated in package.json: react/).to_stdout
      end

      it 'raises YarnError on upgrade failure' do
        allow(Open3).to receive(:capture3).with('yarn upgrade react', chdir: Rails.root)
                                          .and_return(['', 'Upgrade failed', double(success?: false)])
        
        expect { core.send(:yarn_update!, 'react') }.to raise_error(UmdSync::YarnError, /Failed to update react/)
      end
    end

    describe '#remove_package_via_yarn' do
      it 'removes package successfully' do
        allow(Open3).to receive(:capture3).with('yarn remove react', chdir: Rails.root)
                                          .and_return(['', '', double(success?: true)])
        
        expect { core.send(:remove_package_via_yarn, 'react') }.to output(/Removed from package.json: react/).to_stdout
      end

      it 'raises YarnError on removal failure' do
        allow(Open3).to receive(:capture3).with('yarn remove react', chdir: Rails.root)
                                          .and_return(['', 'Remove failed', double(success?: false)])
        
        expect { core.send(:remove_package_via_yarn, 'react') }.to raise_error(UmdSync::YarnError, /Failed to remove react/)
      end
    end
  end

  describe 'helper methods' do
    describe '#url_accessible?' do
      it 'returns true for accessible URLs' do
        stub_request(:get, 'https://example.com/test').to_return(status: 200)
        
        expect(core.send(:url_accessible?, 'https://example.com/test')).to be true
      end

      it 'returns false for 404 URLs' do
        stub_request(:get, 'https://example.com/missing').to_return(status: 404)
        
        expect(core.send(:url_accessible?, 'https://example.com/missing')).to be false
      end

      it 'returns false for network errors' do
        stub_request(:get, 'https://example.com/error').to_raise(StandardError)
        
        expect(core.send(:url_accessible?, 'https://example.com/error')).to be false
      end
    end

    describe '#has_partial?' do
      it 'returns true when partial exists' do
        partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'umd')
        FileUtils.mkdir_p(partials_dir)
        File.write(File.join(partials_dir, '_react.html.erb'), '<script>')
        
        expect(core.send(:has_partial?, 'react')).to be true
      end

      it 'returns false when partial does not exist' do
        expect(core.send(:has_partial?, 'vue')).to be false
      end
    end

    describe '#get_global_name_for_package' do
      it 'delegates to detect_global_name' do
        allow(core).to receive(:detect_global_name).with('react').and_return('React')
        
        result = core.send(:get_global_name_for_package, 'react')
        
        expect(result).to eq('React')
        expect(core).to have_received(:detect_global_name).with('react')
      end
    end

    describe '#reset_webpack_externals' do
      it 'resets externals block in webpack config' do
        webpack_content = <<~JS
          module.exports = {
            externals: {
              "react": "React",
              "lodash": "_"
            },
            output: {}
          };
        JS
        
        File.write(File.join(temp_dir, 'webpack.config.js'), webpack_content)
        
        expect { core.send(:reset_webpack_externals) }.to output(/Reset webpack externals/).to_stdout
        
        updated_content = File.read(File.join(temp_dir, 'webpack.config.js'))
        expect(updated_content).to include('externals: {')
        expect(updated_content).to include('// UmdSync managed externals - do not edit manually')
        expect(updated_content).not_to include('"react": "React"')
      end

      it 'does nothing if webpack config does not exist' do
        File.delete(File.join(temp_dir, 'webpack.config.js')) if File.exist?(File.join(temp_dir, 'webpack.config.js'))
        
        expect { core.send(:reset_webpack_externals) }.not_to output.to_stdout
      end
    end
  end

  describe 'error handling' do
    describe '#install_package!' do
      it 'raises UmdNotFoundError when no UMD build is found' do
        # Add the package to package.json first so it passes the initial check
        create_temp_package_json(temp_dir, {'non-existent-package' => '1.0.0'})
        allow(core).to receive(:find_working_umd_url).and_return(nil)
        
        expect { core.send(:install_package!, 'non-existent-package') }.to raise_error(UmdSync::UmdNotFoundError)
      end

      it 'handles network errors gracefully' do
        allow(core).to receive(:find_working_umd_url).and_raise(StandardError, 'Network timeout')
        
        expect { core.send(:install_package!, 'react') }.to raise_error(StandardError, 'Network timeout')
      end
    end

    describe 'file operations' do
      it 'handles file permission errors' do
        allow(FileUtils).to receive(:mkdir_p).and_raise(Errno::EACCES, 'Permission denied')
        
        expect { core.init! }.to raise_error(Errno::EACCES)
      end

      it 'handles write permission errors' do
        allow(File).to receive(:write).and_raise(Errno::EACCES, 'Permission denied')
        
        expect { core.create_partial_file('react', '<script>', 'React') }.to raise_error(Errno::EACCES)
      end
    end
  end

  describe 'additional coverage' do
    it 'handles package.json parsing with complex versions' do
      create_temp_package_json(temp_dir, {
        'react' => '~18.3.1',
        'vue' => '>=3.0.0',
        'lodash' => 'latest'
      })
      
      expect(core.send(:installed_packages)).to include('react', 'vue', 'lodash')
    end

    it 'generates webpack config with all options' do
      File.delete(File.join(temp_dir, 'webpack.config.js')) if File.exist?(File.join(temp_dir, 'webpack.config.js'))
      
      core.send(:generate_webpack_config!)
      
      config_content = File.read(File.join(temp_dir, 'webpack.config.js'))
      expect(config_content).to include('TerserPlugin')
      expect(config_content).to include('WebpackManifestPlugin')
      expect(config_content).to include('babel-loader')
      expect(config_content).to include('eval-source-map')
    end

    it 'handles partial content generation with special characters' do
      content = core.send(:generate_partial_content, '@scope/package-name', '<script>content</script>', 'GlobalName')
      
      expect(content).to include('GlobalName')
      expect(content).to include('atob(') # Base64 encoded content
      expect(content).to include('createElement') # Dynamic script injection
      expect(content).to include('Generated by UmdSync')
    end

    it 'verifies package installation status correctly' do
      create_temp_package_json(temp_dir, {'installed-package' => '1.0.0'})
      
      expect(core.package_installed?('installed-package')).to be true
      expect(core.package_installed?('missing-package')).to be false
    end

    it 'handles version detection edge cases' do
      create_temp_package_json(temp_dir, {
        'simple-version' => '1.0.0',
        'complex-version' => '^2.3.4-beta.1',
        'range-version' => '>=1.0.0 <2.0.0'
      })
      
      expect(core.version_for('simple-version')).to eq('1.0.0')
      expect(core.version_for('complex-version')).to eq('2.3.4-beta.1')
      expect(core.version_for('range-version')).to match(/\d+\.\d+\.\d+/)
    end
  end
end 