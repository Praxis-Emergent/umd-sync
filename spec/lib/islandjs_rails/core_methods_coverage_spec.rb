require 'spec_helper'

RSpec.describe 'Core Methods Coverage Tests' do
  let(:core) { IslandjsRails.core }
  
  before do
    allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
    allow(Dir).to receive(:pwd).and_return('/tmp/test_app')
  end

  describe 'URL and network methods' do
    describe '#url_accessible?' do
      it 'returns true for accessible URLs' do
        stub_request(:get, "https://example.com/test.js")
          .to_return(status: 200, body: "console.log('test');")
        
        result = core.send(:url_accessible?, 'https://example.com/test.js')
        expect(result).to be true
      end

      it 'returns false for non-accessible URLs' do
        stub_request(:get, "https://example.com/missing.js")
          .to_return(status: 404)
        
        result = core.send(:url_accessible?, 'https://example.com/missing.js')
        expect(result).to be false
      end

      it 'returns false when network error occurs' do
        stub_request(:get, "https://example.com/error.js")
          .to_raise(StandardError.new("Network error"))
        
        result = core.send(:url_accessible?, 'https://example.com/error.js')
        expect(result).to be false
      end
    end

    describe '#download_umd_content' do
      it 'downloads content from accessible URL' do
        stub_request(:get, "https://unpkg.com/react@18.0.0/umd/react.min.js")
          .to_return(status: 200, body: "!function(){console.log('React loaded');}();")
        
        content = core.send(:download_umd_content, 'https://unpkg.com/react@18.0.0/umd/react.min.js')
        expect(content).to include("React loaded")
      end

      it 'raises error for failed downloads' do
        stub_request(:get, "https://unpkg.com/missing@1.0.0/umd/missing.min.js")
          .to_return(status: 404)
        
        expect {
          core.send(:download_umd_content, 'https://unpkg.com/missing@1.0.0/umd/missing.min.js')
        }.to raise_error(IslandjsRails::Error, /Failed to download UMD/)
      end
    end
  end

  describe 'File system methods' do
    describe '#find_application_layout' do
      it 'finds ERB layout' do
        erb_path = '/tmp/test_app/app/views/layouts/application.html.erb'
        haml_path = '/tmp/test_app/app/views/layouts/application.html.haml'
        slim_path = '/tmp/test_app/app/views/layouts/application.html.slim'
        
        allow(File).to receive(:exist?).with(erb_path).and_return(true)
        allow(File).to receive(:exist?).with(haml_path).and_return(false)
        allow(File).to receive(:exist?).with(slim_path).and_return(false)
        
        result = core.send(:find_application_layout)
        expect(result).to eq(erb_path)
      end

      it 'finds HAML layout when ERB not available' do
        erb_path = '/tmp/test_app/app/views/layouts/application.html.erb'
        haml_path = '/tmp/test_app/app/views/layouts/application.html.haml'
        slim_path = '/tmp/test_app/app/views/layouts/application.html.slim'
        
        allow(File).to receive(:exist?).with(erb_path).and_return(false)
        allow(File).to receive(:exist?).with(haml_path).and_return(true)
        allow(File).to receive(:exist?).with(slim_path).and_return(false)
        
        result = core.send(:find_application_layout)
        expect(result).to eq(haml_path)
      end

      it 'returns nil when no layout found' do
        erb_path = '/tmp/test_app/app/views/layouts/application.html.erb'
        haml_path = '/tmp/test_app/app/views/layouts/application.html.haml'
        slim_path = '/tmp/test_app/app/views/layouts/application.html.slim'
        
        allow(File).to receive(:exist?).with(erb_path).and_return(false)
        allow(File).to receive(:exist?).with(haml_path).and_return(false)
        allow(File).to receive(:exist?).with(slim_path).and_return(false)
        
        result = core.send(:find_application_layout)
        expect(result).to be_nil
      end
    end

    describe '#has_partial?' do
      it 'returns true when partial exists' do
        partial_path = '/tmp/test_app/app/views/shared/islands/_react.html.erb'
        allow(File).to receive(:exist?).with(Pathname.new(partial_path)).and_return(true)
        
        result = core.send(:has_partial?, 'react')
        expect(result).to be true
      end

      it 'returns false when partial does not exist' do
        allow(File).to receive(:exist?).and_return(false)
        
        result = core.send(:has_partial?, 'nonexistent')
        expect(result).to be false
      end
    end

    describe '#partial_path_for' do
      it 'generates correct path for simple package name' do
        result = core.send(:partial_path_for, 'react')
        expect(result.to_s).to end_with('app/views/shared/islands/_react.html.erb')
      end

      it 'generates correct path for scoped package name' do
        result = core.send(:partial_path_for, '@babel/core')
        expect(result.to_s).to end_with('app/views/shared/islands/__babel_core.html.erb')
      end

      it 'generates correct path for package with hyphens' do
        result = core.send(:partial_path_for, 'react-dom')
        expect(result.to_s).to end_with('app/views/shared/islands/_react_dom.html.erb')
      end
    end
  end

  describe 'Package management methods' do
    before do
      package_json_path = Pathname.new('/tmp/test_app/package.json')
      allow(File).to receive(:exist?).with(package_json_path).and_return(true)
      allow(File).to receive(:read).with(package_json_path).and_return('{"dependencies": {"react": "^18.0.0", "lodash": "^4.17.21"}}')
    end

    describe '#installed_packages' do
      it 'returns list of installed packages' do
        result = core.send(:installed_packages)
        expect(result).to include('react', 'lodash')
      end

      it 'returns empty array when no package.json' do
        allow(File).to receive(:exist?).and_return(false)
        
        result = core.send(:installed_packages)
        expect(result).to eq([])
      end

      it 'includes devDependencies' do
        package_json_path = Pathname.new('/tmp/test_app/package.json')
        allow(File).to receive(:read).with(package_json_path).and_return('{"dependencies": {"react": "^18.0.0"}, "devDependencies": {"webpack": "^5.0.0"}}')
        
        result = core.send(:installed_packages)
        expect(result).to include('react', 'webpack')
      end
    end

    describe '#get_global_name_for_package' do
      it 'returns global name for package' do
        result = core.send(:get_global_name_for_package, 'react')
        expect(result).to eq('React')
      end

      it 'handles scoped packages' do
        result = core.send(:get_global_name_for_package, '@solana/web3.js')
        expect(result).to eq('solanaWeb3')
      end
    end
  end

  describe 'Build and bundle methods' do
    describe '#build_bundle!' do
      it 'builds bundle successfully in production' do
        allow(ENV).to receive(:[]).with('NODE_ENV').and_return('production')
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn build').and_return(true)
        
        result = core.send(:build_bundle!)
        expect(result).to be true
      end

      it 'builds bundle successfully in development' do
        allow(ENV).to receive(:[]).with('NODE_ENV').and_return('development')
        allow(ENV).to receive(:[]).with('RAILS_ENV').and_return('development')
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn build > /dev/null 2>&1').and_return(true)
        
        result = core.send(:build_bundle!)
        expect(result).to be true
      end

      it 'returns false when yarn not found' do
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(false)
        
        result = core.send(:build_bundle!)
        expect(result).to be false
      end

      it 'installs webpack-cli when missing' do
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(false)
        allow(core).to receive(:system).with('yarn add --dev webpack-cli@^5.1.4').and_return(true)
        allow(core).to receive(:system).with('yarn build > /dev/null 2>&1').and_return(true)
        
        result = core.send(:build_bundle!)
        expect(result).to be true
      end

      it 'returns false when build fails' do
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn list webpack-cli > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('yarn build > /dev/null 2>&1').and_return(false)
        
        result = core.send(:build_bundle!)
        expect(result).to be false
      end
    end
  end

  describe 'Template and file creation methods' do
    describe '#copy_template_file' do
      it 'copies template file when it exists' do
        template_path = '/gem/lib/templates/webpack.config.js'
        destination_path = '/tmp/test_app/webpack.config.js'
        
        allow(File).to receive(:expand_path).and_return('/gem')
        allow(File).to receive(:exist?).with(template_path).and_return(true)
        allow(FileUtils).to receive(:cp)
        
        core.send(:copy_template_file, 'webpack.config.js', destination_path)
        expect(FileUtils).to have_received(:cp).with(template_path, destination_path)
      end

      it 'handles missing template file gracefully' do
        template_path = '/gem/lib/templates/missing.js'
        destination_path = '/tmp/test_app/missing.js'
        
        allow(File).to receive(:expand_path).and_return('/gem')
        allow(File).to receive(:exist?).with(template_path).and_return(false)
        
        expect {
          core.send(:copy_template_file, 'missing.js', destination_path)
        }.not_to raise_error
      end
    end

    describe '#create_partial_file' do
      it 'creates partial file with content' do
        partial_path = Pathname.new('/tmp/test_app/app/views/shared/islands/_react.html.erb')
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)
        allow(core).to receive(:generate_partial_content).and_return('<script>React content</script>')
        
        core.send(:create_partial_file, 'react', 'console.log("React");', 'React')
        
        expect(FileUtils).to have_received(:mkdir_p).with(File.dirname(partial_path))
        expect(File).to have_received(:write).with(partial_path, '<script>React content</script>')
      end
    end
  end

  describe 'Route and demo methods' do
    describe '#demo_route_exists?' do
      it 'returns true when demo route exists' do
        routes_content = "Rails.application.routes.draw do\n  get 'islandjs', to: 'islandjs_demo#index'\nend"
        allow(File).to receive(:exist?).with('/tmp/test_app/config/routes.rb').and_return(true)
        allow(File).to receive(:read).with('/tmp/test_app/config/routes.rb').and_return(routes_content)
        
        result = core.send(:demo_route_exists?)
        expect(result).to be true
      end

      it 'returns false when demo route does not exist' do
        routes_content = "Rails.application.routes.draw do\n  root 'home#index'\nend"
        allow(File).to receive(:exist?).with('/tmp/test_app/config/routes.rb').and_return(true)
        allow(File).to receive(:read).with('/tmp/test_app/config/routes.rb').and_return(routes_content)
        
        result = core.send(:demo_route_exists?)
        expect(result).to be false
      end

      it 'returns false when routes file does not exist' do
        allow(File).to receive(:exist?).with('/tmp/test_app/config/routes.rb').and_return(false)
        
        result = core.send(:demo_route_exists?)
        expect(result).to be false
      end
    end
  end
end
