require 'spec_helper'

RSpec.describe IslandjsRails::CLI do
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
    it 'calls IslandjsRails.init!' do
      expect(IslandjsRails).to receive(:init!)
      cli.init
    end
  end

  describe '#install' do
    it 'calls IslandjsRails.install! with package name' do
      expect(IslandjsRails).to receive(:install!).with('react', nil)
      cli.install('react')
    end
    
    it 'calls IslandjsRails.install! with package name and version' do
      expect(IslandjsRails).to receive(:install!).with('react', '18.3.1')
      cli.install('react', '18.3.1')
    end
  end

  describe '#update' do
    it 'calls IslandjsRails.update! with package name' do
      expect(IslandjsRails).to receive(:update!).with('react', nil)
      cli.update('react')
    end
    
    it 'calls IslandjsRails.update! with package name and version' do
      expect(IslandjsRails).to receive(:update!).with('react', '18.3.1')
      cli.update('react', '18.3.1')
    end
  end

  describe '#sync' do
    it 'calls IslandjsRails.sync!' do
      expect(IslandjsRails).to receive(:sync!)
      cli.sync
    end
  end

  describe '#status' do
    it 'calls IslandjsRails.status!' do
      expect(IslandjsRails).to receive(:status!)
      cli.status
    end
  end

  describe '#clean' do
    it 'calls IslandjsRails.clean!' do
      expect(IslandjsRails).to receive(:clean!)
      cli.clean
    end
  end

  describe '#config' do
    it 'displays configuration information' do
      expect { cli.config }.to output(/IslandjsRails Configuration/).to_stdout
      expect { cli.config }.to output(/Package.json path/).to_stdout
      expect { cli.config }.to output(/Partials directory/).to_stdout
    end
  end

  describe '#version' do
    it 'displays gem version' do
      expect { cli.version }.to output(/IslandjsRails #{IslandjsRails::VERSION}/).to_stdout
    end
  end

  describe '#remove' do
    it 'calls IslandjsRails.remove! with package name' do
      expect(IslandjsRails).to receive(:remove!).with('react')
      cli.remove('react')
    end
  end
end 