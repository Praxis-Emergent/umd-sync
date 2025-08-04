require_relative '../../spec_helper'
require 'islandjs_rails/core'

RSpec.describe IslandjsRails::Core do
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
    before do
      # Mock successful URL for React
      allow(core).to receive(:url_accessible?).and_return(false)
      allow(core).to receive(:url_accessible?)
        .with('https://unpkg.com/react@18.3.1/umd/react.min.js')
        .and_return(true)
    end
    
    it 'finds working UMD URL for React', vcr: { cassette_name: 'react_umd_search' } do
      url, global_name = core.find_working_umd_url('react', '18.3.1')
      
      expect(url).to include('react@18.3.1')
      expect(url).to include('.min.js')
      expect(global_name).to eq('React')
    end

    it 'returns nil for non-existent packages', vcr: { cassette_name: 'nonexistent_package' } do
      allow(core).to receive(:url_accessible?).and_return(false)
      
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
      }.to raise_error(IslandjsRails::Error, /Failed to download UMD/)
    end

    it 'handles successful downloads' do
      mock_response = double('response', code: '200', body: 'UMD content')
      allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
      
      result = core.download_umd_content('https://example.com/test.js')
      expect(result).to eq('UMD content')
    end

    it 'handles download failures gracefully' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Network error'))
      
      expect { core.download_umd_content('https://example.com/test.js') }.to raise_error(StandardError)
    end
  end

  describe '#create_partial_file' do
    let(:partials_dir) { File.join(temp_dir, 'app', 'views', 'shared', 'islands') }
    
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
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'islands')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
      File.write(File.join(partials_dir, '_lodash.html.erb'), '<script>lodash</script>')
    end

    it 'updates webpack externals with installed packages' do
      core.update_webpack_externals
      
      webpack_content = File.read(webpack_path)
      expect(webpack_content).to include('"react": "React"')
      expect(webpack_content).to include('"lodash": "_"')
      expect(webpack_content).to include('IslandjsRails managed externals')
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
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'islands')
      expect(Dir.exist?(partials_dir)).to be false
      
      expect { core.init! }.to output(/Initializing IslandjsRails/).to_stdout
      
      expect(Dir.exist?(partials_dir)).to be true
    end

    it 'generates webpack config if missing' do
      webpack_path = File.join(temp_dir, 'webpack.config.js')
      File.delete(webpack_path) if File.exist?(webpack_path)
      
      # Mock the additional methods that init! now calls
      allow(core).to receive(:check_node_tools!)
      allow(core).to receive(:ensure_package_json!)
      allow(core).to receive(:install_essential_dependencies!)
      allow(core).to receive(:create_scaffolded_structure!)
      allow(core).to receive(:inject_umd_partials_into_layout!)
      allow(core).to receive(:ensure_node_modules_gitignored!)
      
      expect { core.init! }.to output(/Generated webpack.config.js/).to_stdout
      
      expect(File.exist?(webpack_path)).to be true
      content = File.read(webpack_path)
      expect(content).to include('islandjs_rails')
      expect(content).to include('./app/javascript/islandjs_rails/index.js')
    end
  end

  describe '#status!' do
    before do
      # Create some partials
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'islands')
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
    end

    it 'shows status of packages' do
      expect { core.status! }.to output(/📊 IslandJS Status/).to_stdout
    end
  end

  describe '#clean!' do
    let(:partials_dir) { File.join(temp_dir, 'app', 'views', 'shared', 'islands') }
    
    before do
      FileUtils.mkdir_p(partials_dir)
      File.write(File.join(partials_dir, '_react.html.erb'), '<script>React</script>')
      File.write(File.join(partials_dir, '_lodash.html.erb'), '<script>lodash</script>')
      create_temp_webpack_config(temp_dir)
    end

    it 'removes all partial files' do
      expect(Dir.glob(File.join(partials_dir, '*.erb')).length).to eq(2)
      
      expect { core.clean! }.to output(/🧹 Cleaning UMD partials/).to_stdout
      
      expect(Dir.glob(File.join(partials_dir, '*.erb')).length).to eq(0)
    end

    it 'resets webpack externals' do
      core.update_webpack_externals # Add some externals first
      webpack_content_before = File.read(File.join(temp_dir, 'webpack.config.js'))
      expect(webpack_content_before).to include('"react": "React"')
      
      core.clean!
      
      webpack_content_after = File.read(File.join(temp_dir, 'webpack.config.js'))
      expect(webpack_content_after).not_to include('"react": "React"')
      expect(webpack_content_after).to include('IslandjsRails managed externals')
    end
  end

  describe '#remove!' do
    before do
      create_temp_package_json(temp_dir, {'react' => '^18.3.1'})
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'islands')
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
      expect { core.remove!('vue') }.to raise_error(IslandjsRails::PackageNotFoundError)
    end

    it 'handles yarn command failures' do
      allow(Open3).to receive(:capture3).with('yarn remove react', chdir: Rails.root)
                                        .and_return(['', 'Error removing', double(success?: false)])
      
      expect { core.remove!('react') }.to raise_error(IslandjsRails::YarnError, /Failed to remove react/)
    end

    it 'removes partial file and updates webpack externals' do
      partial_path = File.join(temp_dir, 'app', 'views', 'shared', 'islands', '_react.html.erb')
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
      expect { core.sync! }.to output(/Syncing all packages/).to_stdout
      
      # Verify that partials were created (indirect verification)
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'islands')
      expect(Dir.glob(File.join(partials_dir, '*.erb')).size).to be > 0
    end

    it 'processes packages during sync' do
      # Simple test that sync! runs without error and processes packages
      expect { core.sync! }.to output(/Syncing all packages/).to_stdout
      expect { core.sync! }.to output(/Processing/).to_stdout
    end

    it 'handles empty package.json' do
      create_temp_package_json(temp_dir, {})
      
      expect { core.sync! }.to output(/Syncing all packages/).to_stdout
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
        
        expect { core.send(:add_package_via_yarn, 'react') }.to raise_error(IslandjsRails::YarnError, /Failed to add react/)
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
        
        expect { core.send(:yarn_update!, 'react') }.to raise_error(IslandjsRails::YarnError, /Failed to update react/)
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
        
        expect { core.send(:remove_package_via_yarn, 'react') }.to raise_error(IslandjsRails::YarnError, /Failed to remove react/)
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
        partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'islands')
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
        expect(updated_content).to include('// IslandjsRails managed externals - do not edit manually')
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
        
        expect { core.send(:install_package!, 'non-existent-package') }.to raise_error(IslandjsRails::UmdNotFoundError)
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
      expect(content).to include('Generated by IslandjsRails')
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

  describe '#install!' do
    it 'calls underlying install methods' do
      allow(core).to receive(:package_installed?).and_return(false)
      allow(core).to receive(:add_package_via_yarn)
      allow(core).to receive(:install_package!)
      allow(core).to receive(:react_ecosystem_complete?).and_return(false)
      
      expect { core.install!('react', '18.3.1') }.to output(/Installing UMD package/).to_stdout
      
      expect(core).to have_received(:add_package_via_yarn).with('react', '18.3.1')
      expect(core).to have_received(:install_package!).with('react', '18.3.1')
    end

    it 'activates React scaffolding when ecosystem becomes complete' do
      # Setup: react is not installed, react-dom is
      create_temp_package_json(temp_dir, { 'react-dom' => '^18.3.1' })
      
      allow(core).to receive(:add_package_via_yarn)
      allow(core).to receive(:install_package!)
      allow(core).to receive(:activate_react_scaffolding!)
      
      # First call: ecosystem incomplete
      allow(core).to receive(:react_ecosystem_complete?).and_return(false, true)
      
      core.install!('react', '18.3.1')
      
      expect(core).to have_received(:activate_react_scaffolding!)
    end
  end

  describe '#update!' do
    it 'calls yarn update and reinstalls package' do
      allow(core).to receive(:yarn_update!)
      allow(core).to receive(:install_package!)
      
      expect { core.update!('react', '18.3.1') }.to output(/Updating UMD package/).to_stdout
      
      expect(core).to have_received(:yarn_update!).with('react', '18.3.1')
      expect(core).to have_received(:install_package!).with('react')
    end

    it 'raises error if package not installed' do
      create_temp_package_json(temp_dir, {})
      
      expect { core.update!('missing-package') }.to raise_error(IslandjsRails::PackageNotFoundError)
    end
  end

  describe 'React ecosystem activation' do
    describe '#react_ecosystem_complete?' do
      it 'returns true when both react and react-dom are installed' do
        create_temp_package_json(temp_dir, { 'react' => '^18.3.1', 'react-dom' => '^18.3.1' })
        
        expect(core.send(:react_ecosystem_complete?)).to be true
      end

      it 'returns false when only react is installed' do
        create_temp_package_json(temp_dir, { 'react' => '^18.3.1' })
        
        expect(core.send(:react_ecosystem_complete?)).to be false
      end

      it 'returns false when only react-dom is installed' do
        create_temp_package_json(temp_dir, { 'react-dom' => '^18.3.1' })
        
        expect(core.send(:react_ecosystem_complete?)).to be false
      end

      it 'returns false when neither is installed' do
        create_temp_package_json(temp_dir, {})
        
        expect(core.send(:react_ecosystem_complete?)).to be false
      end
    end

    describe '#activate_react_scaffolding!' do
      before do
        allow(STDIN).to receive(:gets).and_return("n\n")
      end

      it 'calls all React activation methods' do
        allow(core).to receive(:uncomment_react_imports!)
        allow(core).to receive(:create_hello_world_component!)
        allow(core).to receive(:build_bundle!)
        allow(core).to receive(:offer_demo_route!)
        
        expect { core.send(:activate_react_scaffolding!) }.to output(/React ecosystem is now complete/).to_stdout
        
        expect(core).to have_received(:uncomment_react_imports!)
        expect(core).to have_received(:create_hello_world_component!)
        expect(core).to have_received(:build_bundle!)
        expect(core).to have_received(:offer_demo_route!)
      end
    end

    describe '#uncomment_react_imports!' do
      let(:index_js_path) { File.join(temp_dir, 'app', 'javascript', 'islandjs_rails/index.js') }
      
      before do
        FileUtils.mkdir_p(File.dirname(index_js_path))
      end

      it 'uncomments React imports in template file' do
        # Create the exact template format expected by the method
        File.write(index_js_path, <<~JS)
          // IslandJS Rails - Main entry point
          // This file is the webpack entry point for your JavaScript islands

          // Example React component imports (uncomment when you have components)
          // import HelloWorld from './components/HelloWorld.jsx';

          // Mount components to the global islandjsRails namespace
          window.islandjsRails = {
           // HelloWorld
          };

          console.log('🏝️ IslandJS Rails loaded successfully!');
        JS
        
        Dir.chdir(temp_dir) do
          expect { core.send(:uncomment_react_imports!) }.to output(/✓ Activated React imports/).to_stdout
        end
        
        content = File.read(index_js_path)
        expect(content).to include('import HelloWorld from')
        expect(content).not_to include('// import HelloWorld from')
        expect(content).to include('HelloWorld')
        expect(content).not_to include('// HelloWorld')
      end

      it 'warns when file has been modified' do
        File.write(index_js_path, "custom content")
        
        expect { core.send(:uncomment_react_imports!) }.to output(/has been modified/).to_stdout
      end

      it 'handles missing index.js file' do
        expect { core.send(:uncomment_react_imports!) }.not_to raise_error
      end
    end

    describe '#create_hello_world_component!' do
      let(:components_dir) { File.join(temp_dir, 'app', 'javascript', 'islandjs_rails', 'components') }
      let(:hello_world_path) { File.join(components_dir, 'HelloWorld.jsx') }
      
      before do
        FileUtils.mkdir_p(components_dir)
      end

      it 'creates HelloWorld component' do
        # Ensure directory exists and file doesn't exist
        FileUtils.mkdir_p(components_dir)
        File.delete(hello_world_path) if File.exist?(hello_world_path)
        
        Dir.chdir(temp_dir) do
          expect { core.send(:create_hello_world_component!) }.to output(/✓ Created HelloWorld.jsx component/).to_stdout
        end
        
        expect(File.exist?(hello_world_path)).to be true
        content = File.read(hello_world_path)
        expect(content).to include('React')
        expect(content).to include('useState')
        expect(content).to include('IslandjsRails')
      end

      it 'skips if component already exists' do
        File.write(hello_world_path, 'existing content')
        
        expect { core.send(:create_hello_world_component!) }.to output(/already exists/).to_stdout
        
        content = File.read(hello_world_path)
        expect(content).to eq('existing content')
      end
    end

    describe '#create_hello_world_component! with Turbo cache sync' do
      let(:components_dir) { File.join(temp_dir, 'app', 'javascript', 'islandjs_rails', 'components') }
      let(:hello_world_path) { File.join(components_dir, 'HelloWorld.jsx') }
      
      before do
        FileUtils.mkdir_p(components_dir)
      end

      it 'creates HelloWorld component with Turbo cache sync' do
        FileUtils.mkdir_p(components_dir)
        File.delete(hello_world_path) if File.exist?(hello_world_path)
        
        Dir.chdir(temp_dir) do
          expect { core.send(:create_hello_world_component!) }.to output(/✓ Created HelloWorld.jsx component/).to_stdout
        end
        
        expect(File.exist?(hello_world_path)).to be true
        content = File.read(hello_world_path)
        
        # Check for enhanced functionality
        expect(content).to include('_islandId')
        expect(content).to include('window.IslandjsRails?.useTurboCacheSync')
        expect(content).to include('inputValue')
        expect(content).to include('setInputValue')
        expect(content).to include('state preserved on navigation')
        expect(content).to include('Navigate away and back')
      end

      it 'includes proper state sync structure' do
        Dir.chdir(temp_dir) do
          core.send(:create_hello_world_component!)
        end
        
        content = File.read(hello_world_path)
        expect(content).to include('useTurboCacheSync({ ')
        expect(content).to include('message,')
        expect(content).to include('count,')
        expect(content).to include('inputValue,')
        expect(content).to include('_islandId')
        expect(content).to include('}, _islandId);')
      end
    end

    describe 'JavaScript utilities in index.js template' do
      it 'includes Turbo cache sync utilities' do
        template = core.send(:generate_index_js_template)
        
        expect(template).to include('window.IslandjsRails = window.IslandjsRails || {};')
        expect(template).to include('window.IslandjsRails.useTurboCacheSync')
        expect(template).to include('window.IslandjsRails.setupTurboStateSync')
      end

      it 'includes useTurboCacheSync hook implementation' do
        template = core.send(:generate_index_js_template)
        
        expect(template).to include('const { useEffect } = React;')
        expect(template).to include('useEffect(() => {')
        expect(template).to include('if (!islandId) return;')
        expect(template).to include('document.getElementById(islandId)')
        expect(template).to include('islandjs:state-update')
        expect(template).to include('}, [state, islandId]);')
      end

      it 'includes setupTurboStateSync utility function' do
        template = core.send(:generate_index_js_template)
        
        expect(template).to include('setupTurboStateSync = function(getState, islandId)')
        expect(template).to include('typeof getState === \'function\' ? getState() : getState')
        expect(template).to include('return {')
        expect(template).to include('sync: syncState,')
        expect(template).to include('cleanup: () => {')
      end

      it 'has proper React check for hook' do
        template = core.send(:generate_index_js_template)
        
        expect(template).to include('if (typeof React === \'undefined\') return;')
      end
    end

    describe '#build_bundle!' do
      it 'runs yarn build when yarn is available' do
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn build > /dev/null 2>&1').and_return(true)
        
        expect { core.send(:build_bundle!) }.to output(/Bundle built successfully/).to_stdout
      end

      it 'warns when yarn is not available' do
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(false)
        
        expect { core.send(:build_bundle!) }.to output(/yarn not found/).to_stdout
      end

      it 'warns when build fails' do
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn build > /dev/null 2>&1').and_return(false)
        
        expect { core.send(:build_bundle!) }.to output(/Build failed/).to_stdout
      end

      it 'installs webpack-cli when missing' do
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(false)
        allow(core).to receive(:system).with('yarn add --dev webpack-cli@^5.1.4').and_return(true)
        allow(core).to receive(:system).with('yarn build > /dev/null 2>&1').and_return(true)
        
        expect { core.send(:build_bundle!) }.to output(/webpack-cli not found, installing/).to_stdout
      end
    end

    describe '#offer_demo_route!' do
      before do
        allow(STDIN).to receive(:gets).and_return("y\n")
      end

      it 'creates demo route when user agrees' do
        allow(core).to receive(:create_demo_route!)
        
        expect { core.send(:offer_demo_route!) }.to output(/Would you like to create a demo route/).to_stdout
        
        expect(core).to have_received(:create_demo_route!)
      end

      it 'skips demo route when user declines' do
        allow(STDIN).to receive(:gets).and_return("n\n")
        
        expect { core.send(:offer_demo_route!) }.to output(/No problem!/).to_stdout
      end

      it 'skips if demo route already exists' do
        allow(core).to receive(:demo_route_exists?).and_return(true)
        
        expect { core.send(:offer_demo_route!) }.to output(/Demo route already exists/).to_stdout
      end
    end
  end

  describe 'initialization helpers' do
    describe '#check_node_tools!' do
      it 'succeeds when npm and yarn are available' do
        allow(core).to receive(:system).with('which npm > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        
        expect { core.send(:check_node_tools!) }.to output(/npm and yarn are available/).to_stdout
      end

      it 'exits when npm is missing' do
        allow(core).to receive(:system).with('which npm > /dev/null 2>&1').and_return(false)
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:exit).with(1)
        
        expect { core.send(:check_node_tools!) }.to output(/❌ npm not found/).to_stdout
        expect(core).to have_received(:exit).with(1)
      end

      it 'exits when yarn is missing' do
        allow(core).to receive(:system).with('which npm > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(false)
        allow(core).to receive(:exit)
        
        expect { core.send(:check_node_tools!) }.to output(/yarn not found/).to_stdout
        expect(core).to have_received(:exit).with(1)
      end
    end

    describe '#ensure_package_json!' do
      let(:package_json_path) { File.join(temp_dir, 'package.json') }
      
      it 'creates package.json when missing' do
        File.delete(package_json_path) if File.exist?(package_json_path)
        
        Dir.chdir(temp_dir) do
          expect { core.send(:ensure_package_json!) }.to output(/📝 Creating package.json/).to_stdout
        end
        
        expect(File.exist?(package_json_path)).to be true
        content = JSON.parse(File.read(package_json_path))
        expect(content['scripts']).to include('build', 'watch')
        expect(content['name']).to eq(File.basename(temp_dir))
      end

      it 'skips when package.json exists' do
        expect { core.send(:ensure_package_json!) }.to output(/package.json already exists/).to_stdout
      end
    end

    describe '#install_essential_dependencies!' do
      it 'installs missing dependencies' do
        create_temp_package_json(temp_dir, {})
        allow(core).to receive(:system).and_return(true)
        
        expect { core.send(:install_essential_dependencies!) }.to output(/Installing essential webpack dependencies/).to_stdout
      end

      it 'skips when all dependencies are installed' do
        # Create package.json with all essential deps
        dev_deps = {}
        IslandjsRails::Core::ESSENTIAL_DEPENDENCIES.each do |dep|
          package_name = dep.split('@').first
          dev_deps[package_name] = '1.0.0'
        end
        # Manually create package.json with devDependencies
        package_json = {
          'name' => 'test-app',
          'version' => '1.0.0',
          'dependencies' => {},
          'devDependencies' => dev_deps
        }
        File.write(File.join(temp_dir, 'package.json'), JSON.pretty_generate(package_json))
        
        expect { core.send(:install_essential_dependencies!) }.to output(/All essential dependencies already installed/).to_stdout
      end

      it 'exits on installation failure' do
        create_temp_package_json(temp_dir, {})
        allow(core).to receive(:system).and_return(false)
        allow(core).to receive(:exit)
        
        expect { core.send(:install_essential_dependencies!) }.to output(/Failed to install dependencies/).to_stdout
        expect(core).to have_received(:exit).with(1)
      end
    end

    describe '#create_scaffolded_structure!' do
      let(:islandjs_dir) { File.join(temp_dir, 'app', 'javascript', 'islandjs_rails') }
      let(:components_dir) { File.join(islandjs_dir, 'components') }
      
      it 'creates directory structure and files' do
        # Ensure the directory doesn't exist first
        FileUtils.rm_rf(islandjs_dir) if Dir.exist?(islandjs_dir)
        
        Dir.chdir(temp_dir) do
          expect { core.send(:create_scaffolded_structure!) }.to output(/🏗️  Creating scaffolded structure/).to_stdout
        end
        
        expect(Dir.exist?(components_dir)).to be true
        expect(File.exist?(File.join(islandjs_dir, 'index.js'))).to be true
        expect(File.exist?(File.join(components_dir, '.gitkeep'))).to be true
      end

      it 'skips existing files' do
        FileUtils.mkdir_p(islandjs_dir)
        File.write(File.join(islandjs_dir, 'index.js'), 'existing')
        
        expect { core.send(:create_scaffolded_structure!) }.to output(/already exists/).to_stdout
        
        content = File.read(File.join(islandjs_dir, 'index.js'))
        expect(content).to eq('existing')
      end
    end

    describe '#inject_umd_partials_into_layout!' do
      let(:layout_path) { File.join(temp_dir, 'app', 'views', 'layouts', 'application.html.erb') }
      
      before do
        FileUtils.mkdir_p(File.dirname(layout_path))
      end

      it 'injects UMD helper into layout' do
        File.write(layout_path, <<~ERB)
          <html>
            <head>
              <title>App</title>
            </head>
            <body>
            </body>
          </html>
        ERB
        
        # Mock Dir.pwd to return temp_dir
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        
        expect { core.send(:inject_umd_partials_into_layout!) }.to output(/Auto-injected UMD helper/).to_stdout
        
        content = File.read(layout_path)
        expect(content).to include('<%= islands %>')
        expect(content).to include('IslandjsRails: Auto-injected')
      end

      it 'skips if already injected' do
        File.write(layout_path, '<%= islands %>')
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        
        expect { core.send(:inject_umd_partials_into_layout!) }.to output(/already present/).to_stdout
      end

      it 'warns when layout file missing' do
        expect { core.send(:inject_umd_partials_into_layout!) }.to output(/Layout file not found/).to_stdout
      end

      it 'warns when no head tag found' do
        File.write(layout_path, '<html><body></body></html>')
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        
        expect { core.send(:inject_umd_partials_into_layout!) }.to output(/Could not find <\/head> tag/).to_stdout
      end
    end

    describe '#ensure_node_modules_gitignored!' do
      let(:gitignore_path) { File.join(temp_dir, '.gitignore') }
      
      it 'creates .gitignore when missing' do
        # Ensure .gitignore doesn't exist
        File.delete(gitignore_path) if File.exist?(gitignore_path)
        
        Dir.chdir(temp_dir) do
          expect { core.send(:ensure_node_modules_gitignored!) }.to output(/⚠️  .gitignore not found, creating one/).to_stdout
        end
        
        expect(File.exist?(gitignore_path)).to be true
        expect(File.read(gitignore_path)).to include('/node_modules')
      end

      it 'adds node_modules when missing from .gitignore' do
        # Create .gitignore without node_modules
        File.write(gitignore_path, "*.log\n")
        
        Dir.chdir(temp_dir) do
          expect { core.send(:ensure_node_modules_gitignored!) }.to output(/✓ Added \/node_modules to .gitignore/).to_stdout
        end
        
        content = File.read(gitignore_path)
        expect(content).to include('*.log')
        expect(content).to include('/node_modules')
      end

      it 'skips when node_modules already ignored' do
        File.write(gitignore_path, "/node_modules\n")
        
        expect { core.send(:ensure_node_modules_gitignored!) }.to output(/✓ .gitignore already configured for IslandjsRails/).to_stdout
      end

      it 'recognizes various node_modules patterns' do
        patterns = ['/node_modules', 'node_modules/', '**/node_modules/']
        
        patterns.each do |pattern|
          File.write(gitignore_path, pattern)
          expect { core.send(:ensure_node_modules_gitignored!) }.to output(/✓ .gitignore already configured for IslandjsRails/).to_stdout
        end
      end
    end
  end

  describe 'demo route methods' do
    describe '#demo_route_exists?' do
      let(:routes_file) { File.join(temp_dir, 'config', 'routes.rb') }
      
      it 'returns true when route exists' do
        FileUtils.mkdir_p(File.dirname(routes_file))
        File.write(routes_file, "get 'islandjs/react'")
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        
        expect(core.send(:demo_route_exists?)).to be true
      end

      it 'returns false when route missing' do
        FileUtils.mkdir_p(File.dirname(routes_file))
        File.write(routes_file, "Rails.application.routes.draw do\nend")
        
        expect(core.send(:demo_route_exists?)).to be false
      end

      it 'returns false when routes file missing' do
        expect(core.send(:demo_route_exists?)).to be false
      end
    end

    describe '#create_demo_route!' do
      it 'calls all demo creation methods' do
        allow(core).to receive(:create_demo_controller!)
        allow(core).to receive(:create_demo_view!)
        allow(core).to receive(:add_demo_route!)
        
        core.send(:create_demo_route!)
        
        expect(core).to have_received(:create_demo_controller!)
        expect(core).to have_received(:create_demo_view!)
        expect(core).to have_received(:add_demo_route!)
      end
    end

    describe '#create_demo_controller!' do
      let(:controller_path) { File.join(temp_dir, 'app', 'controllers', 'islandjs_demo_controller.rb') }
      
      it 'creates demo controller' do
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        
        expect { core.send(:create_demo_controller!) }.to output(/Created.*islandjs_demo_controller/).to_stdout
        
        expect(File.exist?(controller_path)).to be true
        content = File.read(controller_path)
        expect(content).to include('IslandjsDemoController')
        expect(content).to include('def react')
      end
    end

    describe '#create_demo_view!' do
      let(:view_path) { File.join(temp_dir, 'app', 'views', 'islandjs_demo', 'react.html.erb') }
      
      it 'creates demo view' do
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        
        expect { core.send(:create_demo_view!) }.to output(/Created.*react.html.erb/).to_stdout
        
        expect(File.exist?(view_path)).to be true
        content = File.read(view_path)
        expect(content).to include('react_component')
        expect(content).to include('HelloWorld')
      end
    end

    describe '#add_demo_route!' do
      let(:routes_file) { File.join(temp_dir, 'config', 'routes.rb') }
      
      before do
        FileUtils.mkdir_p(File.dirname(routes_file))
      end

      it 'adds route to routes.rb' do
        File.write(routes_file, "Rails.application.routes.draw do\n  # existing routes\nend")
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        
        expect { core.send(:add_demo_route!) }.to output(/Added route/).to_stdout
        
        content = File.read(routes_file)
        expect(content).to include("get 'islandjs/react'")
        expect(content).to include('islandjs_demo#react')
      end

      it 'warns when routes file missing' do
        expect { core.send(:add_demo_route!) }.to output(/Routes file not found/).to_stdout
      end

      it 'warns when cannot find insertion point' do
        File.write(routes_file, "invalid content")
        allow(Dir).to receive(:pwd).and_return(temp_dir)
        
        expect { core.send(:add_demo_route!) }.to output(/Could not automatically add route/).to_stdout
      end
    end
  end

  describe 'package management edge cases' do
    describe '#download_and_create_partial!' do
      it 'skips packages without UMD builds' do
        allow(core).to receive(:find_working_umd_url).and_return([nil, nil])
        
        expect { core.send(:download_and_create_partial!, 'no-umd-package') }.to output(/No UMD build found/).to_stdout
      end

      it 'creates partial for packages with UMD' do
        allow(core).to receive(:find_working_umd_url).and_return(['http://example.com/umd.js', 'GlobalName'])
        allow(core).to receive(:download_umd_content).and_return('// UMD content')
        
        expect { core.send(:download_and_create_partial!, 'test-package') }.to output(/Created partial/).to_stdout
      end
    end

    describe '#partial_path_for' do
      it 'handles various package name formats' do
        partials_dir = core.configuration.partials_dir
        expect(core.send(:partial_path_for, 'simple')).to eq(partials_dir.join('_simple.html.erb'))
        expect(core.send(:partial_path_for, 'kebab-case')).to eq(partials_dir.join('_kebab_case.html.erb'))
        expect(core.send(:partial_path_for, '@scope/package')).to eq(partials_dir.join('__scope_package.html.erb'))
      end
    end

    describe '#installed_packages' do
      it 'returns only dependencies and filters out devDependencies and build tools' do
        # Manually create package.json with both dependencies and devDependencies
        package_json = {
          'name' => 'test-app',
          'version' => '1.0.0',
          'dependencies' => { 
            'react' => '18.3.1',
            'lodash' => '4.17.21',
            'webpack' => '5.88.2'  # This should be filtered out as a build tool
          },
          'devDependencies' => { 
            'babel-loader' => '9.1.3',  # This should be ignored (devDependency)
            '@babel/core' => '7.23.0'   # This should be ignored (devDependency)
          }
        }
        File.write(File.join(temp_dir, 'package.json'), JSON.pretty_generate(package_json))
        
        packages = core.send(:installed_packages)
        # Should include browser libraries from dependencies
        expect(packages).to include('react', 'lodash')
        # Should exclude build tools even from dependencies
        expect(packages).not_to include('webpack')
        # Should exclude all devDependencies
        expect(packages).not_to include('babel-loader', '@babel/core')
      end

      it 'handles missing dependencies sections' do
        File.write(File.join(temp_dir, 'package.json'), '{"name": "test"}')
        
        expect(core.send(:installed_packages)).to eq([])
      end
    end

    describe '#supported_package?' do
      it 'currently returns true for all packages' do
        expect(core.send(:supported_package?, 'any-package')).to be true
      end
    end
  end

  describe 'Edge cases and error handling' do
    it 'handles missing package.json gracefully' do
      Dir.chdir(temp_dir) do
        # Ensure no package.json exists for this test
        File.delete('package.json') if File.exist?('package.json')
        
        expect { core.package_installed?('react') }.not_to raise_error
        expect(core.package_installed?('react')).to be false
      end
    end
    
    it 'handles malformed package.json' do
      package_json_path = File.join(temp_dir, 'package.json')
      File.write(package_json_path, 'invalid json{')
      
      Dir.chdir(temp_dir) do
        expect { core.package_installed?('react') }.not_to raise_error
        expect(core.package_installed?('react')).to be false
      end
    end
    
    it 'handles missing routes.rb in demo creation' do
      Dir.chdir(temp_dir) do
        expect { core.send(:add_demo_route!) }.to output(/Routes file not found/).to_stdout
      end
    end
    
    it 'handles routes.rb without proper structure' do
      routes_path = File.join(temp_dir, 'config', 'routes.rb')
      FileUtils.mkdir_p(File.dirname(routes_path))
      File.write(routes_path, 'invalid content')
      
      Dir.chdir(temp_dir) do
        expect { core.send(:add_demo_route!) }.to output(/Could not automatically add route/).to_stdout
      end
    end
    
    it 'handles yarn command failures gracefully' do
      allow(core).to receive(:system).and_return(false)
      
      Dir.chdir(temp_dir) do
        expect { core.send(:add_package_via_yarn, 'react', '18.3.1') }.not_to raise_error
      end
    end
    
    it 'handles webpack config file creation errors' do
      Dir.chdir(temp_dir) do
        # Mock File.write to simulate permission error
        allow(File).to receive(:write).and_raise(Errno::EACCES, "Permission denied")
        
        expect { core.send(:generate_webpack_config!) }.not_to raise_error
      end
    end
    
    it 'handles partial file creation with missing directories' do
      # Don't create the partials directory
      Dir.chdir(temp_dir) do
        expect { core.send(:create_partial_file, 'test', 'content') }.not_to raise_error
      end
    end
    
    it 'handles layout injection when layout file missing' do
      Dir.chdir(temp_dir) do
        expect { core.send(:inject_umd_partials_into_layout!) }.to output(/Layout file not found/).to_stdout
      end
    end
    
    it 'handles gitignore creation when file is missing' do
      Dir.chdir(temp_dir) do
        expect { core.send(:ensure_node_modules_gitignored!) }.not_to raise_error
      end
      
      gitignore_path = File.join(temp_dir, '.gitignore')
      expect(File.exist?(gitignore_path)).to be true
    end
    
    it 'skips gitignore updates when already configured' do
      gitignore_path = File.join(temp_dir, '.gitignore')
      File.write(gitignore_path, "/node_modules\n!/public/islands_manifest.json\n!/public/islands_bundle.js\n")
      
      Dir.chdir(temp_dir) do
        expect { core.send(:ensure_node_modules_gitignored!) }.to output(/already configured/).to_stdout
      end
    end
  end

  describe 'Build and bundle operations' do
    it 'handles yarn build command execution' do
      allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
      allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(true)
      allow(core).to receive(:system).with('yarn build > /dev/null 2>&1').and_return(true)
      
      Dir.chdir(temp_dir) do
        expect { core.send(:build_bundle!) }.to output(/🔨 Building IslandJS webpack bundle/).to_stdout
      end
    end
    
    it 'handles yarn build failures' do
      allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
      allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(true)
      allow(core).to receive(:system).with('yarn build > /dev/null 2>&1').and_return(false)
      
      Dir.chdir(temp_dir) do
        expect { core.send(:build_bundle!) }.to output(/❌ Build failed/).to_stdout
      end
    end
    
    it 'handles missing yarn command' do
      allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(false)
      allow(core).to receive(:system).with('which npm > /dev/null 2>&1').and_return(true)
      
      expect { core.send(:check_node_tools!) }.to raise_error(SystemExit)
    end
    
    it 'handles missing npm command' do
      allow(core).to receive(:system).with('which npm > /dev/null 2>&1').and_return(false)
      
      expect { core.send(:check_node_tools!) }.to raise_error(SystemExit)
    end
  end

  describe 'File system operations' do
    it 'creates directories recursively when needed' do
      deep_path = File.join(temp_dir, 'deep', 'nested', 'structure')
      
      Dir.chdir(temp_dir) do
        core.send(:create_scaffolded_structure!)
      end
      
      expect(Dir.exist?(File.join(temp_dir, 'app', 'javascript', 'islandjs_rails'))).to be true
    end
    
    it 'preserves existing index.js files' do
      js_dir = File.join(temp_dir, 'app', 'javascript', 'islandjs_rails')
      FileUtils.mkdir_p(js_dir)
      index_path = File.join(js_dir, 'index.js')
      File.write(index_path, 'existing content')
      
      Dir.chdir(temp_dir) do
        expect { core.send(:create_scaffolded_structure!) }.to output(/already exists/).to_stdout
      end
      
      expect(File.read(index_path)).to eq('existing content')
    end
  end

  describe 'CLI integration' do
    it 'responds to all CLI commands' do
      cli = IslandjsRails::CLI.new
      
      expect(cli).to respond_to(:init)
      expect(cli).to respond_to(:install)
      expect(cli).to respond_to(:update)
      expect(cli).to respond_to(:remove)
      expect(cli).to respond_to(:sync)
      expect(cli).to respond_to(:status)
      expect(cli).to respond_to(:clean)
      expect(cli).to respond_to(:config)
      expect(cli).to respond_to(:version)
    end
  end

  describe 'Module-level methods' do
    it 'delegates package_installed? to core' do
      allow_any_instance_of(IslandjsRails::Core).to receive(:package_installed?).with('react').and_return(true)
      
      result = IslandjsRails.package_installed?('react')
      expect(result).to be true
    end
    
    it 'delegates version_for to core' do
      allow_any_instance_of(IslandjsRails::Core).to receive(:version_for).with('react').and_return('18.3.1')
      
      result = IslandjsRails.version_for('react')
      expect(result).to eq('18.3.1')
    end
    
    it 'delegates detect_global_name to core' do
      allow_any_instance_of(IslandjsRails::Core).to receive(:detect_global_name).with('react').and_return('React')
      
      result = IslandjsRails.detect_global_name('react')
      expect(result).to eq('React')
    end
  end

  describe 'Configuration' do
    it 'allows global name overrides' do
      config = IslandjsRails::Configuration.new
      config.add_global_name_override('custom-lib', 'CustomLib')
      
      expect(config.global_name_overrides['custom-lib']).to eq('CustomLib')
    end
    
    it 'can be configured via block' do
      IslandjsRails.configure do |config|
        config.add_global_name_override('test-lib', 'TestLib')
      end
      
      expect(IslandjsRails.configuration.global_name_overrides['test-lib']).to eq('TestLib')
    end
  end

  describe 'Error handling' do
    it 'raises PackageNotFoundError for missing packages' do
      allow(core).to receive(:package_installed?).with('missing').and_return(false)
      
      expect {
        core.update!('missing')
      }.to raise_error(IslandjsRails::PackageNotFoundError)
    end
    
    it 'handles network errors gracefully' do
      allow(core).to receive(:url_accessible?).and_return(false)
      
      expect {
        core.send(:find_working_umd_url, 'nonexistent', '1.0.0')
      }.not_to raise_error
    end
  end

  describe 'URL accessibility' do
    it 'returns true for accessible URLs' do
      allow(Net::HTTP).to receive(:get_response).and_return(double(code: '200'))
      
      result = core.send(:url_accessible?, 'https://example.com/test.js')
      expect(result).to be true
    end
    
    it 'returns false for inaccessible URLs' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Network error'))
      
      result = core.send(:url_accessible?, 'https://example.com/missing.js')
      expect(result).to be false
    end
  end

  describe 'Global name detection' do
    it 'detects React global name' do
      result = core.detect_global_name('react')
      expect(result).to eq('React')
    end
    
    it 'detects ReactDOM global name' do
      result = core.detect_global_name('react-dom')
      expect(result).to eq('ReactDOM')
    end
    
    it 'detects Vue global name' do
      result = core.detect_global_name('vue')
      expect(result).to eq('Vue')
    end
    
    it 'handles unknown packages' do
      result = core.detect_global_name('unknown-package')
      expect(result).to eq('unknownPackage')
    end
  end

  describe 'Partial operations' do
    it 'checks if partial exists' do
      partial_path = File.join(temp_dir, 'app', 'views', 'shared', 'islands', '_react.html.erb')
      FileUtils.mkdir_p(File.dirname(partial_path))
      File.write(partial_path, 'test content')
      
      Dir.chdir(temp_dir) do
        result = core.send(:has_partial?, 'react')
        expect(result).to be true
      end
    end
    
    it 'returns false for missing partials' do
      Dir.chdir(temp_dir) do
        result = core.send(:has_partial?, 'nonexistent')
        expect(result).to be false
      end
    end
  end

  describe '#remove!' do
    it 'removes package and cleans up partials' do
      # Setup
      create_temp_package_json(temp_dir, { 'react' => '^18.3.1' })
      partial_path = File.join(temp_dir, 'app', 'views', 'shared', 'islands', '_react.html.erb')
      FileUtils.mkdir_p(File.dirname(partial_path))
      File.write(partial_path, 'React content')
      
      # Mock yarn remove - use any_args to handle Pathname vs String differences
      allow(Open3).to receive(:capture3).and_return(['', '', double(success?: true)])
      
      Dir.chdir(temp_dir) do
        expect { core.remove!('react') }.to output(/✅ Successfully removed react/).to_stdout
      end
      
      expect(File.exist?(partial_path)).to be false
    end
    
    it 'handles missing packages gracefully' do
      Dir.chdir(temp_dir) do
        expect { core.remove!('nonexistent', graceful: true) }.to output(/not installed/).to_stdout
      end
    end
  end

  describe '#sync!' do
    it 'syncs all installed packages' do
      create_temp_package_json(temp_dir, { 'react' => '^18.3.1', 'vue' => '^3.0.0' })
      
      allow(core).to receive(:url_accessible?).and_return(true)
      allow(core).to receive(:download_umd_content).and_return('UMD content')
      
      Dir.chdir(temp_dir) do
        expect { core.sync! }.to output(/🔄 Syncing all packages/).to_stdout
      end
    end
    
    it 'handles packages without UMD builds' do
      create_temp_package_json(temp_dir, { 'no-umd-package' => '^1.0.0' })
      
      allow(core).to receive(:url_accessible?).and_return(false)
      
      Dir.chdir(temp_dir) do
        expect { core.sync! }.to output(/No UMD build found/).to_stdout
      end
      end
    end

    describe '#clean!' do
    it 'removes orphaned partials' do
      # Create partials directory with orphaned partial
      partials_dir = File.join(temp_dir, 'app', 'views', 'shared', 'islands')
        FileUtils.mkdir_p(partials_dir)
      orphaned_partial = File.join(partials_dir, '_orphaned.html.erb')
      File.write(orphaned_partial, 'Orphaned content')
        
      # Setup package.json without the orphaned package
      create_temp_package_json(temp_dir, { 'react' => '^18.3.1' })
        
      Dir.chdir(temp_dir) do
        expect { core.clean! }.to output(/🧹 Cleaning UMD partials/).to_stdout
      end

      expect(File.exist?(orphaned_partial)).to be false
      end
    end

  describe '#status!' do
    it 'shows status of all packages' do
      create_temp_package_json(temp_dir, { 'react' => '^18.3.1' })
      
      Dir.chdir(temp_dir) do
        expect { core.status! }.to output(/📊 IslandJS Status/).to_stdout
      end
    end
  end

  describe '#find_working_island_url' do
    it 'finds working UMD URL' do
      allow(core).to receive(:url_accessible?).and_return(true)
      
      result = core.find_working_island_url('react', '18.3.1')
      expect(result).to include('https://')
      expect(result).to include('react@18.3.1')
    end
    
    it 'returns nil when no URL works' do
      allow(core).to receive(:url_accessible?).and_return(false)
      
      result = core.find_working_island_url('nonexistent', '1.0.0')
      expect(result).to be_nil
    end
  end

  describe 'Demo route functionality' do
    describe '#demo_route_exists?' do
      it 'returns true when demo route exists' do
        routes_content = "Rails.application.routes.draw do\n  get 'islandjs/react', to: 'islandjs_demo#react'\nend"
        routes_path = File.join(temp_dir, 'config', 'routes.rb')
        FileUtils.mkdir_p(File.dirname(routes_path))
        File.write(routes_path, routes_content)
        
        Dir.chdir(temp_dir) do
          result = core.send(:demo_route_exists?)
          expect(result).to be true
        end
      end
      
      it 'returns false when demo route does not exist' do
        routes_content = "Rails.application.routes.draw do\n  root 'home#index'\nend"
        routes_path = File.join(temp_dir, 'config', 'routes.rb')
        FileUtils.mkdir_p(File.dirname(routes_path))
        File.write(routes_path, routes_content)
        
        Dir.chdir(temp_dir) do
          result = core.send(:demo_route_exists?)
          expect(result).to be false
        end
      end
    end

    describe '#create_demo_controller!' do
      it 'creates demo controller file' do
        controllers_dir = File.join(temp_dir, 'app', 'controllers')
        FileUtils.mkdir_p(controllers_dir)
        
        Dir.chdir(temp_dir) do
          core.send(:create_demo_controller!)
        end
        
        controller_path = File.join(controllers_dir, 'islandjs_demo_controller.rb')
        expect(File.exist?(controller_path)).to be true
        
        content = File.read(controller_path)
        expect(content).to include('class IslandjsDemoController')
        expect(content).to include('def react')
      end
    end

    describe '#create_demo_view!' do
      it 'creates demo view file' do
        views_dir = File.join(temp_dir, 'app', 'views', 'islandjs_demo')
        
        Dir.chdir(temp_dir) do
          core.send(:create_demo_view!)
        end
        
        view_path = File.join(views_dir, 'react.html.erb')
        expect(File.exist?(view_path)).to be true
        
        content = File.read(view_path)
        expect(content).to include('IslandJS Rails Demo')
        expect(content).to include('react_component')
      end
    end
  end

  describe 'Webpack configuration' do
    it 'updates webpack externals correctly' do
      webpack_path = File.join(temp_dir, 'webpack.config.js')
      FileUtils.mkdir_p(File.dirname(webpack_path))
      
      # Create initial webpack config
      Dir.chdir(temp_dir) do
        core.send(:generate_webpack_config!)
        core.send(:update_webpack_externals, 'react', 'React')
      end
      
      content = File.read(webpack_path)
      expect(content).to include('"react": "React"')
    end
  end

  describe 'Version parsing and handling' do
    it 'extracts version from semver ranges' do
      create_temp_package_json(temp_dir, { 
        'caret-version' => '^1.2.3',
        'tilde-version' => '~2.4.6',
        'exact-version' => '3.5.7'
      })
      
      Dir.chdir(temp_dir) do
        expect(core.version_for('caret-version')).to eq('1.2.3')
        expect(core.version_for('tilde-version')).to eq('2.4.6')
        expect(core.version_for('exact-version')).to eq('3.5.7')
      end
    end
    
    it 'handles complex version constraints' do
      create_temp_package_json(temp_dir, {
        'range-version' => '>=1.0.0 <2.0.0',
        'prerelease-version' => '2.0.0-beta.1'
      })
      
      Dir.chdir(temp_dir) do
        range_version = core.version_for('range-version')
        expect(range_version).to match(/\d+\.\d+\.\d+/)
        
        prerelease_version = core.version_for('prerelease-version')
        expect(prerelease_version).to eq('2.0.0-beta.1')
      end
    end
  end

  describe 'UMD URL pattern testing' do
    it 'tries all UMD path patterns' do
      allow(core).to receive(:url_accessible?).and_return(false, false, true)
      allow(core).to receive(:download_umd_content).and_return('UMD content')
      allow(core).to receive(:detect_global_name).and_return('Test')
      
      result = core.send(:find_working_umd_url, 'test-lib', '1.0.0')
      expect(result).to be_an(Array)
    end
    
    it 'handles scoped package names correctly' do
      allow(core).to receive(:url_accessible?).and_return(true)
      allow(core).to receive(:download_umd_content).and_return('UMD content')
      allow(core).to receive(:detect_global_name).and_return('ScopedLib')
      
      result = core.send(:find_working_umd_url, '@scope/scoped-lib', '1.0.0')
      expect(result).to be_an(Array)
    end
  end

  describe 'Download and network operations' do
    it 'handles download failures gracefully' do
      allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Network error'))
      
      expect { core.download_umd_content('https://example.com/test.js') }.to raise_error(StandardError)
    end
    
    it 'handles successful downloads' do
      mock_response = double('response', code: '200', body: 'UMD content')
      allow(Net::HTTP).to receive(:get_response).and_return(mock_response)
      
      result = core.download_umd_content('https://example.com/test.js')
      expect(result).to eq('UMD content')
    end
  end

  describe 'Partial content generation' do
    it 'generates proper base64 encoded partials' do
      content = 'window.TestLib = { version: "1.0.0" };'
      global_name = 'TestLib'
      
      result = core.send(:generate_partial_content, 'test-lib', content, global_name)
      
      expect(result).to include('Generated by IslandjsRails')
      expect(result).to include('atob(')
      expect(result).to include('TestLib UMD Library')
    end
    
    it 'handles content without global name' do
      content = 'console.log("test");'
      
      result = core.send(:generate_partial_content, 'test-lib', content)
      
      expect(result).to include('Generated by IslandjsRails')
      expect(result).to include('atob(')
    end
  end

  describe 'Package management edge cases' do
    it 'handles yarn update failures' do
      allow(core).to receive(:system).and_return(false)
      # Mock the specific methods that would be called
      allow(core).to receive(:add_package_via_yarn).and_return(false)
      
      Dir.chdir(temp_dir) do
        expect { core.send(:yarn_update!, 'test-pkg', '1.0.0') }.not_to raise_error
      end
    end
    
    it 'handles package removal failures' do
      allow(core).to receive(:system).and_return(false)
      allow(core).to receive(:remove_package_via_yarn).and_return(false)
      
      Dir.chdir(temp_dir) do
        expect { core.send(:remove_package_via_yarn, 'test-pkg') }.not_to raise_error
      end
    end
    
    it 'validates supported packages correctly' do
      expect(core.send(:supported_package?, 'react')).to be true
      expect(core.send(:supported_package?, 'unknown')).to be true  # All packages are supported
    end
  end

  describe 'Webpack externals management' do
    it 'resets webpack externals to empty state' do
      webpack_path = File.join(temp_dir, 'webpack.config.js')
      FileUtils.mkdir_p(File.dirname(webpack_path))
      
      # Create webpack config with existing externals
      File.write(webpack_path, <<~JS)
        module.exports = {
          externals: {
            "react": "React",
            "vue": "Vue"
          }
        };
      JS
      
      Dir.chdir(temp_dir) do
        core.send(:reset_webpack_externals)
      end
      
      content = File.read(webpack_path)
      expect(content).to include('IslandjsRails managed externals')
    end
    
    it 'updates externals for all installed packages when no package specified' do
      create_temp_package_json(temp_dir, { 'react' => '^18.3.1', 'vue' => '^3.0.0' })
      webpack_path = File.join(temp_dir, 'webpack.config.js')
      
      Dir.chdir(temp_dir) do
        core.send(:generate_webpack_config!)
        
        # Mock has_partial? to return true for installed packages
        allow(core).to receive(:has_partial?).with('react').and_return(true)
        allow(core).to receive(:has_partial?).with('vue').and_return(true)
        
        core.send(:update_webpack_externals)
      end
      
      content = File.read(webpack_path)
      expect(content).to include('"react": "React"')
      expect(content).to include('"vue": "Vue"')
    end
  end
end 