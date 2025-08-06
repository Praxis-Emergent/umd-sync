require 'spec_helper'

RSpec.describe IslandjsRails::VendorManager do
  let(:configuration) { IslandjsRails.configuration }
  let(:vendor_manager) { described_class.new(configuration) }
  let(:vendor_dir) { Pathname.new('/tmp/test_vendor') }
  let(:partials_dir) { Pathname.new('/tmp/test_partials') }

  before do
    allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
    allow(configuration).to receive(:vendor_dir).and_return(vendor_dir)
    allow(configuration).to receive(:partials_dir).and_return(partials_dir)
    allow(configuration).to receive(:vendor_manifest_path).and_return(vendor_dir.join('manifest.json'))
    allow(configuration).to receive(:vendor_partial_path).and_return(partials_dir.join('_vendor_umd.html.erb'))
    allow(configuration).to receive(:vendor_file_path).and_return(vendor_dir.join('react-18.0.0.min.js'))
    allow(configuration).to receive(:vendor_script_mode).and_return(:external_split)
    allow(FileUtils).to receive(:mkdir_p)
    allow(File).to receive(:write)
  end

  describe '#install_package!' do
    context 'when download succeeds' do
      before do
        allow(vendor_manager).to receive(:download_umd_content).and_return(['console.log("react");', '18.0.0'])
        allow(vendor_manager).to receive(:update_manifest!)
        allow(vendor_manager).to receive(:regenerate_vendor_partial!)
      end

      it 'installs package successfully' do
        result = vendor_manager.install_package!('react', '18.0.0')
        expect(result).to be true
      end

      it 'creates vendor directory' do
        vendor_manager.install_package!('react', '18.0.0')
        expect(FileUtils).to have_received(:mkdir_p).with(vendor_dir)
      end

      it 'writes content to vendor file' do
        vendor_manager.install_package!('react', '18.0.0')
        expect(File).to have_received(:write).with(vendor_dir.join('react-18.0.0.min.js'), 'console.log("react");')
      end

      it 'updates manifest' do
        vendor_manager.install_package!('react', '18.0.0')
        expect(vendor_manager).to have_received(:update_manifest!).with('react', '18.0.0', 'react-18.0.0.min.js')
      end

      it 'regenerates vendor partial' do
        vendor_manager.install_package!('react', '18.0.0')
        expect(vendor_manager).to have_received(:regenerate_vendor_partial!)
      end
    end

    context 'when download fails' do
      before do
        allow(vendor_manager).to receive(:download_umd_content).and_return([nil, nil])
      end

      it 'returns false' do
        result = vendor_manager.install_package!('react', '18.0.0')
        expect(result).to be false
      end
    end
  end

  describe '#remove_package!' do
    let(:manifest) { { 'libs' => [{ 'name' => 'react', 'version' => '18.0.0', 'file' => 'react-18.0.0.min.js' }] } }

    before do
      allow(vendor_manager).to receive(:read_manifest).and_return(manifest)
      allow(vendor_manager).to receive(:write_manifest)
      allow(vendor_manager).to receive(:regenerate_vendor_partial!)
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:delete)
    end

    it 'removes package from manifest' do
      vendor_manager.remove_package!('react')
      expect(vendor_manager).to have_received(:write_manifest).with({ 'libs' => [] })
    end

    it 'deletes vendor file if it exists' do
      vendor_manager.remove_package!('react')
      expect(File).to have_received(:delete).with(vendor_dir.join('react-18.0.0.min.js'))
    end

    it 'regenerates vendor partial' do
      vendor_manager.remove_package!('react')
      expect(vendor_manager).to have_received(:regenerate_vendor_partial!)
    end
  end

  describe '#download_umd_content' do
    let(:core) { double('core') }

    before do
      allow(IslandjsRails).to receive(:core).and_return(core)
      allow(core).to receive(:version_for).and_return('18.0.0')
      allow(core).to receive(:find_working_island_url).and_return('https://unpkg.com/react@18.0.0/umd/react.min.js')
      allow(core).to receive(:download_umd_content).and_return('console.log("react");')
      allow(vendor_manager).to receive(:extract_version_from_url).and_return('18.0.0')
    end

    it 'returns content and version when successful' do
      content, version = vendor_manager.send(:download_umd_content, 'react', '18.0.0')
      expect(content).to eq('console.log("react");')
      expect(version).to eq('18.0.0')
    end

    context 'when URL is not found' do
      before do
        allow(core).to receive(:find_working_island_url).and_return(nil)
      end

      it 'returns nil values' do
        content, version = vendor_manager.send(:download_umd_content, 'react', '18.0.0')
        expect(content).to be_nil
        expect(version).to be_nil
      end
    end

    context 'when download fails' do
      before do
        allow(core).to receive(:download_umd_content).and_return(nil)
      end

      it 'returns nil values' do
        content, version = vendor_manager.send(:download_umd_content, 'react', '18.0.0')
        expect(content).to be_nil
        expect(version).to be_nil
      end
    end
  end

  describe '#read_manifest' do
    context 'when manifest file exists' do
      before do
        allow(File).to receive(:exist?).with(vendor_dir.join('manifest.json')).and_return(true)
        allow(File).to receive(:read).with(vendor_dir.join('manifest.json')).and_return('{"libs": []}')
      end

      it 'returns parsed manifest' do
        result = vendor_manager.send(:read_manifest)
        expect(result).to eq({ 'libs' => [] })
      end
    end

    context 'when manifest file does not exist' do
      before do
        allow(File).to receive(:exist?).with(vendor_dir.join('manifest.json')).and_return(false)
      end

      it 'returns empty manifest' do
        result = vendor_manager.send(:read_manifest)
        expect(result).to eq({ 'libs' => [] })
      end
    end

    context 'when manifest file is malformed' do
      before do
        allow(File).to receive(:exist?).with(vendor_dir.join('manifest.json')).and_return(true)
        allow(File).to receive(:read).with(vendor_dir.join('manifest.json')).and_return('invalid json')
      end

      it 'returns empty manifest' do
        result = vendor_manager.send(:read_manifest)
        expect(result).to eq({ 'libs' => [] })
      end
    end
  end

  describe '#regenerate_vendor_partial!' do
    context 'in split mode' do
      before do
        allow(configuration).to receive(:vendor_script_mode).and_return(:external_split)
        allow(vendor_manager).to receive(:generate_split_partial!)
      end

      it 'generates split partial' do
        vendor_manager.send(:regenerate_vendor_partial!)
        expect(vendor_manager).to have_received(:generate_split_partial!)
      end
    end

    context 'in combined mode' do
      before do
        allow(configuration).to receive(:vendor_script_mode).and_return(:external_combined)
        allow(vendor_manager).to receive(:generate_combined_partial!)
      end

      it 'generates combined partial' do
        vendor_manager.send(:regenerate_vendor_partial!)
        expect(vendor_manager).to have_received(:generate_combined_partial!)
      end
    end
  end

  describe '#generate_split_partial!' do
    let(:manifest) { { 'libs' => [{ 'name' => 'react', 'file' => 'react-18.0.0.min.js' }] } }

    before do
      allow(vendor_manager).to receive(:read_manifest).and_return(manifest)
      allow(vendor_manager).to receive(:write_vendor_partial)
    end

    it 'generates partial with script tags for each library' do
      vendor_manager.send(:generate_split_partial!)
      expect(vendor_manager).to have_received(:write_vendor_partial) do |content|
        expect(content).to include('IslandJS Rails Vendor UMD Scripts (Split Mode)')
        expect(content).to include('react-18.0.0.min.js')
      end
    end
  end

  describe '#generate_combined_partial!' do
    context 'when combined info exists' do
      let(:manifest) { { 'combined' => { 'file' => 'combined-abc123.js', 'size_kb' => 150.5 } } }

      before do
        allow(vendor_manager).to receive(:read_manifest).and_return(manifest)
        allow(vendor_manager).to receive(:write_vendor_partial)
      end

      it 'generates combined partial' do
        vendor_manager.send(:generate_combined_partial!)
        expect(vendor_manager).to have_received(:write_vendor_partial) do |content|
          expect(content).to include('IslandJS Rails Vendor UMD Scripts (Combined Mode)')
          expect(content).to include('combined-abc123.js')
          expect(content).to include('150.5KB')
        end
      end
    end

    context 'when no combined info exists' do
      let(:manifest) { { 'libs' => [] } }

      before do
        allow(vendor_manager).to receive(:read_manifest).and_return(manifest)
        allow(vendor_manager).to receive(:generate_split_partial!)
      end

      it 'falls back to split partial' do
        vendor_manager.send(:generate_combined_partial!)
        expect(vendor_manager).to have_received(:generate_split_partial!)
      end
    end
  end

  describe '#order_libraries' do
    let(:libs) do
      [
        { 'name' => 'lodash', 'version' => '4.0.0' },
        { 'name' => 'react', 'version' => '18.0.0' },
        { 'name' => 'react-dom', 'version' => '18.0.0' },
        { 'name' => 'axios', 'version' => '1.0.0' }
      ]
    end

    before do
      allow(configuration).to receive(:vendor_order).and_return(['react', 'react-dom'])
    end

    it 'orders libraries according to vendor_order, then alphabetically' do
      result = vendor_manager.send(:order_libraries, libs)
      names = result.map { |lib| lib['name'] }
      expect(names).to eq(['react', 'react-dom', 'axios', 'lodash'])
    end
  end

  describe '#build_combined_content' do
    let(:ordered_libs) do
      [
        { 'name' => 'react', 'version' => '18.0.0', 'file' => 'react-18.0.0.min.js' },
        { 'name' => 'lodash', 'version' => '4.0.0', 'file' => 'lodash-4.0.0.min.js' }
      ]
    end

    before do
      allow(File).to receive(:exist?).and_return(true)
      allow(File).to receive(:read).with(vendor_dir.join('react-18.0.0.min.js')).and_return('console.log("react");')
      allow(File).to receive(:read).with(vendor_dir.join('lodash-4.0.0.min.js')).and_return('console.log("lodash");')
    end

    it 'combines content from all libraries with headers' do
      result = vendor_manager.send(:build_combined_content, ordered_libs)
      expect(result).to include('// react@18.0.0')
      expect(result).to include('console.log("react");')
      expect(result).to include('// lodash@4.0.0')
      expect(result).to include('console.log("lodash");')
    end

    context 'when vendor file does not exist' do
      before do
        allow(File).to receive(:exist?).with(vendor_dir.join('react-18.0.0.min.js')).and_return(false)
      end

      it 'skips missing files' do
        result = vendor_manager.send(:build_combined_content, ordered_libs)
        expect(result).not_to include('// react@18.0.0')
        expect(result).to include('// lodash@4.0.0')
      end
    end
  end
end
