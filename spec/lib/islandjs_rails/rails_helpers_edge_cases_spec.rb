require 'spec_helper'

RSpec.describe IslandjsRails::RailsHelpers do
  let(:view_context) { ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil) }
  
  before do
    allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
  end

  describe '#island_partials' do
    context 'when vendor UMD partial is missing' do
      before do
        allow(view_context).to receive(:render).and_raise(ActionView::MissingTemplate.new([], 'shared/islands/vendor_umd', [], false, 'html'))
      end

      it 'returns development warning in development' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        
        result = view_context.island_partials
        expect(result).to include('IslandJS: Vendor UMD partial missing')
        expect(result).to include('rails islandjs:init')
      end

      it 'returns empty string in production' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        
        result = view_context.island_partials
        expect(result).to eq('')
      end
    end
  end

  describe '#umd_partial_for' do
    context 'when vendor UMD partial is missing' do
      before do
        allow(view_context).to receive(:render).and_raise(ActionView::MissingTemplate.new([], 'shared/islands/vendor_umd', [], false, 'html'))
      end

      it 'returns development warning in development' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        
        result = view_context.umd_partial_for('react')
        expect(result).to include('umd_partial_for')
        expect(result).to include('is deprecated')
      end

      it 'returns empty string in production' do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        
        result = view_context.umd_partial_for('react')
        expect(result).to eq('')
      end
    end

    it 'shows deprecation warning in development' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
      allow(view_context).to receive(:render).and_return('<script>test</script>')
      
      result = view_context.umd_partial_for('react')
      expect(result).to include('umd_partial_for')
      expect(result).to include('is deprecated')
    end

    it 'delegates to vendor partial in production' do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      allow(view_context).to receive(:render).and_return('<script>vendor</script>')
      
      result = view_context.umd_partial_for('react')
      expect(result).to eq('<script>vendor</script>')
    end
  end

  describe '#island_bundle_script' do
    let(:manifest_path) { Rails.root.join('public', 'islands_manifest.json') }

    context 'when manifest file does not exist' do
      before do
        allow(File).to receive(:exist?).with(manifest_path).and_return(false)
      end

      it 'returns fallback script tag' do
        result = view_context.island_bundle_script
        expect(result).to include('<script src="/islands_bundle.js" defer>')
      end
    end

    context 'when manifest file exists but is malformed' do
      before do
        allow(File).to receive(:exist?).with(manifest_path).and_return(true)
        allow(File).to receive(:read).with(manifest_path).and_return('invalid json')
      end

      it 'returns fallback script tag on JSON parse error' do
        result = view_context.island_bundle_script
        expect(result).to include('<script src="/islands_bundle.js" defer>')
      end
    end

    context 'when manifest exists but does not contain islands_bundle.js' do
      before do
        allow(File).to receive(:exist?).with(manifest_path).and_return(true)
        allow(File).to receive(:read).with(manifest_path).and_return('{"other_bundle.js": "/other_bundle.hash.js"}')
      end

      it 'returns fallback script tag' do
        result = view_context.island_bundle_script
        expect(result).to include('<script src="/islands_bundle.js" defer>')
      end
    end

    context 'when manifest contains islands_bundle.js' do
      before do
        allow(File).to receive(:exist?).with(manifest_path).and_return(true)
        allow(File).to receive(:read).with(manifest_path).and_return('{"islands_bundle.js": "/islands_bundle.abc123.js"}')
      end

      it 'returns script tag with hashed filename' do
        result = view_context.island_bundle_script
        expect(result).to include('<script src="/islands_bundle.abc123.js" defer>')
      end
    end
  end

  describe '#umd_versions_debug' do
    context 'in production environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'returns empty string' do
        result = view_context.umd_versions_debug
        expect(result).to be_nil
      end
    end

    context 'in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        allow(IslandjsRails.core).to receive(:installed_packages).and_return({'react' => '18.0.0'})
        allow(IslandjsRails.core).to receive(:supported_package?).and_return(true)
        allow(IslandjsRails).to receive(:version_for).and_return('18.0.0')
      end

      it 'returns debug div with package versions' do
        result = view_context.umd_versions_debug
        expect(result).to include('UMD:')
        expect(result).to include('18.0.0')
        expect(result).to include('position: fixed')
      end

      context 'when no packages are supported' do
        before do
          allow(IslandjsRails.core).to receive(:installed_packages).and_return({})
        end

        it 'returns no packages message' do
          result = view_context.umd_versions_debug
          expect(result).to include('UMD: No packages')
        end
      end

      context 'when version lookup fails' do
        before do
          allow(IslandjsRails).to receive(:version_for).and_raise(StandardError.new('Version error'))
        end

        it 'shows error in version display' do
          result = view_context.umd_versions_debug
          expect(result).to include('error')
        end
      end

      context 'when core methods raise exceptions' do
        before do
          allow(IslandjsRails.core).to receive(:installed_packages).and_raise(StandardError.new('Core error'))
        end

        it 'returns error div' do
          result = view_context.umd_versions_debug
          expect(result).to include('UMD Error: Core error')
          expect(result).to include('background: #f00')
        end
      end
    end
  end

  describe '#island_debug' do
    context 'in production environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'returns empty string' do
        result = view_context.island_debug
        expect(result).to eq('')
      end
    end

    context 'in development environment' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
        allow(view_context).to receive(:find_bundle_path).and_return('/islands_bundle.js')
        allow(Dir).to receive(:glob).and_return(['partial1.html.erb', 'partial2.html.erb'])
        allow(File).to receive(:exist?).and_return(true)
      end

      it 'returns debug information div' do
        result = view_context.island_debug
        expect(result).to include('IslandJS Debug Info')
        expect(result).to include('Bundle Path: /islands_bundle.js')
        expect(result).to include('Partials: 2 found')
        expect(result).to include('Webpack Config: ✓')
        expect(result).to include('Package.json: ✓')
      end

      context 'when bundle path is not found' do
        before do
          allow(view_context).to receive(:find_bundle_path).and_return(nil)
        end

        it 'shows not found message' do
          result = view_context.island_debug
          expect(result).to include('Bundle Path: Not found')
        end
      end
    end
  end

  describe '#islands' do
    before do
      allow(view_context).to receive(:island_partials).and_return('<script>partials</script>')
      allow(view_context).to receive(:island_bundle_script).and_return('<script>bundle</script>')
      allow(view_context).to receive(:umd_versions_debug).and_return('<div>debug</div>')
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('development'))
    end

    it 'combines all island components' do
      result = view_context.islands
      expect(result).to include('<script>partials</script>')
      expect(result).to include('<script>bundle</script>')
      expect(result).to include('<div>debug</div>')
    end

    context 'in production' do
      before do
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
        allow(view_context).to receive(:umd_versions_debug).and_return(nil)
      end

      it 'excludes debug info' do
        result = view_context.islands
        expect(result).to include('<script>partials</script>')
        expect(result).to include('<script>bundle</script>')
        expect(result).not_to include('<div>debug</div>')
      end
    end
  end
end
