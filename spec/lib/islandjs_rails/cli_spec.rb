require 'spec_helper'

RSpec.describe UmdSync::CLI do
  let(:temp_dir) { create_temp_dir }
  let(:cli) { described_class.new }
  
  before do
    mock_rails_root(temp_dir)
    create_temp_package_json(temp_dir, {
      'react' => '^18.3.1',
      'lodash' => '^4.17.21'
    })
  end

  describe '#init' do
    it 'calls UmdSync.init!' do
      expect(UmdSync).to receive(:init!)
      cli.init
    end
  end

  describe '#install' do
    it 'calls UmdSync.install! with package name' do
      expect(UmdSync).to receive(:install!).with('react', nil)
      cli.install('react')
    end
    
    it 'calls UmdSync.install! with package name and version' do
      expect(UmdSync).to receive(:install!).with('react', '18.3.1')
      cli.install('react', '18.3.1')
    end
  end

  describe '#update' do
    it 'calls UmdSync.update! with package name' do
      expect(UmdSync).to receive(:update!).with('react', nil)
      cli.update('react')
    end
    
    it 'calls UmdSync.update! with package name and version' do
      expect(UmdSync).to receive(:update!).with('react', '18.3.1')
      cli.update('react', '18.3.1')
    end
  end

  describe '#sync' do
    it 'calls UmdSync.sync!' do
      expect(UmdSync).to receive(:sync!)
      cli.sync
    end
  end

  describe '#status' do
    it 'calls UmdSync.status!' do
      expect(UmdSync).to receive(:status!)
      cli.status
    end
  end

  describe '#clean' do
    it 'calls UmdSync.clean!' do
      expect(UmdSync).to receive(:clean!)
      cli.clean
    end
  end

  describe '#config' do
    it 'displays configuration information' do
      expect { cli.config }.to output(/UmdSync Configuration/).to_stdout
      expect { cli.config }.to output(/Package.json path/).to_stdout
      expect { cli.config }.to output(/Partials directory/).to_stdout
    end
  end

  describe '#version' do
    it 'displays gem version' do
      expect { cli.version }.to output(/UmdSync #{UmdSync::VERSION}/).to_stdout
    end
  end

  describe '#remove' do
    it 'calls UmdSync.remove! with package name' do
      expect(UmdSync).to receive(:remove!).with('react')
      cli.remove('react')
    end
  end
end 