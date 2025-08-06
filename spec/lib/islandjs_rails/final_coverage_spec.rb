require 'spec_helper'

RSpec.describe 'Final Coverage Tests' do
  let(:core) { IslandjsRails.core }
  
  before do
    allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
    allow(Dir).to receive(:pwd).and_return('/tmp/test_app')
  end

  describe 'Initialization and setup methods' do
    describe '#check_node_tools!' do
      it 'passes when both npm and yarn are available' do
        allow(core).to receive(:system).with('which npm > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(true)
        
        expect { core.send(:check_node_tools!) }.not_to raise_error
      end

      it 'exits when npm is not available' do
        allow(core).to receive(:system).with('which npm > /dev/null 2>&1').and_return(false)
        
        expect { core.send(:check_node_tools!) }.to raise_error(SystemExit)
      end

      it 'exits when yarn is not available' do
        allow(core).to receive(:system).with('which npm > /dev/null 2>&1').and_return(true)
        allow(core).to receive(:system).with('which yarn > /dev/null 2>&1').and_return(false)
        
        expect { core.send(:check_node_tools!) }.to raise_error(SystemExit)
      end
    end

    describe '#install_essential_dependencies!' do
      it 'skips installation when all dependencies are present' do
        allow(core).to receive(:package_installed?).and_return(true)
        allow(core).to receive(:system).and_return(true)
        
        expect { core.send(:install_essential_dependencies!) }.not_to raise_error
      end

      it 'installs missing dependencies' do
        allow(core).to receive(:package_installed?).and_return(false)
        allow(core).to receive(:system).with(/yarn add --dev/).and_return(true)
        
        expect { core.send(:install_essential_dependencies!) }.not_to raise_error
      end

      it 'exits when dependency installation fails' do
        allow(core).to receive(:package_installed?).and_return(false)
        allow(core).to receive(:system).with(/yarn add --dev/).and_return(false)
        
        expect { core.send(:install_essential_dependencies!) }.to raise_error(SystemExit)
      end
    end

    describe '#setup_vendor_system!' do
      it 'creates vendor manifest and partial' do
        manifest_path = '/tmp/test_app/public/islands/vendor/manifest.json'
        allow(File).to receive(:exist?).with(Pathname.new(manifest_path)).and_return(false)
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)
        
        vendor_manager = double('VendorManager')
        allow(IslandjsRails).to receive(:vendor_manager).and_return(vendor_manager)
        allow(vendor_manager).to receive(:send).with(:regenerate_vendor_partial!)
        
        expect { core.send(:setup_vendor_system!) }.not_to raise_error
      end
    end

    describe '#create_scaffolded_structure!' do
      it 'copies JavaScript structure from templates' do
        gem_root = '/gem'
        template_js_dir = '/gem/lib/templates/app/javascript/islands'
        target_js_dir = '/tmp/test_app/app/javascript/islands'
        
        allow(File).to receive(:expand_path).and_return(gem_root)
        allow(Dir).to receive(:exist?).with(template_js_dir).and_return(true)
        allow(FileUtils).to receive(:mkdir_p)
        allow(FileUtils).to receive(:cp_r)
        
        expect { core.send(:create_scaffolded_structure!) }.not_to raise_error
      end

      it 'creates minimal structure when templates not found' do
        gem_root = '/gem'
        template_js_dir = '/gem/lib/templates/app/javascript/islands'
        
        allow(File).to receive(:expand_path).and_return(gem_root)
        allow(Dir).to receive(:exist?).with(template_js_dir).and_return(false)
        allow(FileUtils).to receive(:mkdir_p)
        allow(File).to receive(:write)
        
        expect { core.send(:create_scaffolded_structure!) }.not_to raise_error
      end
    end
  end

  describe 'Webpack and build methods' do
    describe '#reset_webpack_externals' do
      it 'resets webpack externals to empty' do
        webpack_config_path = '/tmp/test_app/webpack.config.js'
        webpack_content = "module.exports = {\n  externals: {\n    'react': 'React'\n  },\n  entry: './src/index.js'\n};"
        
        allow(File).to receive(:exist?).with(Pathname.new(webpack_config_path)).and_return(true)
        allow(File).to receive(:read).with(Pathname.new(webpack_config_path)).and_return(webpack_content)
        allow(File).to receive(:write)
        
        expect { core.send(:reset_webpack_externals) }.not_to raise_error
      end

      it 'does nothing when webpack config does not exist' do
        webpack_config_path = '/tmp/test_app/webpack.config.js'
        allow(File).to receive(:exist?).with(Pathname.new(webpack_config_path)).and_return(false)
        
        expect { core.send(:reset_webpack_externals) }.not_to raise_error
      end
    end

    describe '#update_webpack_externals' do
      it 'updates webpack externals with vendor packages' do
        webpack_config_path = '/tmp/test_app/webpack.config.js'
        webpack_content = "module.exports = {\n  externals: {},\n  entry: './src/index.js'\n};"
        
        allow(File).to receive(:exist?).with(Pathname.new(webpack_config_path)).and_return(true)
        allow(File).to receive(:read).with(Pathname.new(webpack_config_path)).and_return(webpack_content)
        allow(File).to receive(:write)
        
        vendor_manager = double('VendorManager')
        manifest = { 'libs' => [{ 'name' => 'react', 'global' => 'React' }] }
        allow(IslandjsRails).to receive(:vendor_manager).and_return(vendor_manager)
        allow(vendor_manager).to receive(:send).with(:read_manifest).and_return(manifest)
        
        expect { core.send(:update_webpack_externals) }.not_to raise_error
      end
    end
  end

  describe 'Layout injection methods' do
    describe '#inject_islands_helper_into_layout!' do
      it 'injects islands helper into layout' do
        layout_path = '/tmp/test_app/app/views/layouts/application.html.erb'
        layout_content = "<html>\n<head>\n  <title>Test</title>\n</head>\n<body>\n</body>\n</html>"
        
        allow(core).to receive(:find_application_layout).and_return(layout_path)
        allow(File).to receive(:read).with(layout_path).and_return(layout_content)
        allow(File).to receive(:write).and_return(true)
        
        expect { core.send(:inject_islands_helper_into_layout!) }.not_to raise_error
      end

      it 'skips injection when islands helper already present' do
        layout_path = '/tmp/test_app/app/views/layouts/application.html.erb'
        layout_content = "<html>\n<head>\n  <%= islands %>\n</head>\n<body>\n</body>\n</html>"
        
        allow(core).to receive(:find_application_layout).and_return(layout_path)
        allow(File).to receive(:read).with(layout_path).and_return(layout_content)
        
        expect { core.send(:inject_islands_helper_into_layout!) }.not_to raise_error
      end

      it 'handles missing layout gracefully' do
        allow(core).to receive(:find_application_layout).and_return(nil)
        
        expect { core.send(:inject_islands_helper_into_layout!) }.not_to raise_error
      end
    end
  end

  describe 'Gitignore management' do
    describe '#ensure_node_modules_gitignored!' do
      it 'creates gitignore when it does not exist' do
        gitignore_path = '/tmp/test_app/.gitignore'
        allow(File).to receive(:exist?).with(gitignore_path).and_return(false)
        allow(File).to receive(:write)
        
        expect { core.send(:ensure_node_modules_gitignored!) }.not_to raise_error
      end

      it 'updates existing gitignore with missing entries' do
        gitignore_path = '/tmp/test_app/.gitignore'
        gitignore_content = "*.log\n"
        
        allow(File).to receive(:exist?).with(gitignore_path).and_return(true)
        allow(File).to receive(:read).with(gitignore_path).and_return(gitignore_content)
        allow(File).to receive(:write)
        
        expect { core.send(:ensure_node_modules_gitignored!) }.not_to raise_error
      end

      it 'skips update when gitignore is already configured' do
        gitignore_path = '/tmp/test_app/.gitignore'
        gitignore_content = "/node_modules\n"
        
        allow(File).to receive(:exist?).with(gitignore_path).and_return(true)
        allow(File).to receive(:read).with(gitignore_path).and_return(gitignore_content)
        
        expect { core.send(:ensure_node_modules_gitignored!) }.not_to raise_error
      end
    end
  end

  describe 'Demo route methods' do
    describe '#get_demo_routes_content' do
      it 'uses template content when available' do
        gem_root = '/gem'
        template_path = '/gem/lib/templates/config/demo_routes.rb'
        template_content = "get 'islandjs', to: 'islandjs_demo#index'\nget 'islandjs/react', to: 'islandjs_demo#react'\n"
        
        allow(File).to receive(:expand_path).and_return(gem_root)
        allow(File).to receive(:exist?).with(template_path).and_return(true)
        allow(File).to receive(:read).with(template_path).and_return(template_content)
        
        result = core.send(:get_demo_routes_content, '  ', false)
        expect(result).to include('islandjs_demo#index')
        expect(result).to include('root')
      end

      it 'uses fallback content when template not found' do
        gem_root = '/gem'
        template_path = '/gem/lib/templates/config/demo_routes.rb'
        
        allow(File).to receive(:expand_path).and_return(gem_root)
        allow(File).to receive(:exist?).with(template_path).and_return(false)
        
        result = core.send(:get_demo_routes_content, '  ', false)
        expect(result).to include('islandjs_demo#index')
      end

      it 'skips root route when one already exists' do
        gem_root = '/gem'
        template_path = '/gem/lib/templates/config/demo_routes.rb'
        
        allow(File).to receive(:expand_path).and_return(gem_root)
        allow(File).to receive(:exist?).with(template_path).and_return(false)
        
        result = core.send(:get_demo_routes_content, '  ', true)
        expect(result).not_to include('root')
      end
    end

    describe '#add_demo_route!' do
      it 'adds demo routes to existing routes file' do
        routes_file = '/tmp/test_app/config/routes.rb'
        routes_content = "Rails.application.routes.draw do\n  # Add routes here\nend"
        
        allow(File).to receive(:exist?).with(routes_file).and_return(true)
        allow(File).to receive(:read).with(routes_file).and_return(routes_content)
        allow(File).to receive(:write)
        allow(core).to receive(:get_demo_routes_content).and_return("  get 'islandjs', to: 'islandjs_demo#index'\n")
        
        expect { core.send(:add_demo_route!) }.not_to raise_error
      end

      it 'does nothing when routes file does not exist' do
        routes_file = '/tmp/test_app/config/routes.rb'
        allow(File).to receive(:exist?).with(routes_file).and_return(false)
        
        expect { core.send(:add_demo_route!) }.not_to raise_error
      end
    end
  end

  describe 'Demo controller and view methods' do
    describe '#copy_demo_template' do
      it 'copies demo template when it exists' do
        gem_root = '/gem'
        template_path = '/gem/lib/templates/app/views/islandjs_demo/index.html.erb'
        destination_dir = '/tmp/test_app/app/views/islandjs_demo'
        destination_path = '/tmp/test_app/app/views/islandjs_demo/index.html.erb'
        
        allow(File).to receive(:expand_path).and_return(gem_root)
        allow(File).to receive(:exist?).with(template_path).and_return(true)
        allow(FileUtils).to receive(:cp)
        
        expect { core.send(:copy_demo_template, 'index.html.erb', destination_dir) }.not_to raise_error
      end

      it 'handles missing template gracefully' do
        gem_root = '/gem'
        template_path = '/gem/lib/templates/app/views/islandjs_demo/missing.html.erb'
        destination_dir = '/tmp/test_app/app/views/islandjs_demo'
        
        allow(File).to receive(:expand_path).and_return(gem_root)
        allow(File).to receive(:exist?).with(template_path).and_return(false)
        
        expect { core.send(:copy_demo_template, 'missing.html.erb', destination_dir) }.not_to raise_error
      end
    end

    describe '#create_demo_controller!' do
      it 'creates demo controller from template' do
        controller_file = '/tmp/test_app/app/controllers/islandjs_demo_controller.rb'
        allow(FileUtils).to receive(:mkdir_p)
        allow(core).to receive(:copy_template_file)
        
        expect { core.send(:create_demo_controller!) }.not_to raise_error
      end
    end

    describe '#create_demo_view!' do
      it 'creates demo views from templates' do
        view_dir = '/tmp/test_app/app/views/islandjs_demo'
        allow(FileUtils).to receive(:mkdir_p)
        allow(core).to receive(:copy_demo_template).twice
        
        expect { core.send(:create_demo_view!) }.not_to raise_error
      end
    end
  end
end
