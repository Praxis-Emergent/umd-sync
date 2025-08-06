require 'spec_helper'

RSpec.describe 'IslandJS Rails Error Handling' do
  let(:core) { IslandjsRails.core }
  
  describe 'Network error handling' do
    before do
      allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
      allow(File).to receive(:exist?).and_call_original
      allow(File).to receive(:exist?).with('/tmp/test_app/package.json').and_return(true)
      allow(File).to receive(:read).with('/tmp/test_app/package.json').and_return('{"dependencies": {"react": "^18.0.0"}}')
    end

    describe '#url_accessible?' do
      it 'returns false when URL raises an exception' do
        allow(Net::HTTP).to receive(:get_response).and_raise(StandardError.new('Network error'))
        
        result = core.send(:url_accessible?, 'https://example.com/test.js')
        expect(result).to be false
      end

      it 'returns false when URI is invalid' do
        result = core.send(:url_accessible?, 'invalid-url')
        expect(result).to be false
      end

      it 'returns false for non-200 status codes' do
        response = double('response', code: '404')
        allow(Net::HTTP).to receive(:get_response).and_return(response)
        
        result = core.send(:url_accessible?, 'https://example.com/missing.js')
        expect(result).to be false
      end
    end

    describe '#download_umd_content' do
      it 'raises IslandjsRails::Error for non-200 status' do
        response = double('response', code: '404')
        allow(Net::HTTP).to receive(:get_response).and_return(response)
        
        expect {
          core.send(:download_umd_content, 'https://example.com/missing.js')
        }.to raise_error(IslandjsRails::Error, /Failed to download UMD/)
      end

      it 'returns response body for successful download' do
        response = double('response', code: '200', body: 'console.log("test");')
        allow(Net::HTTP).to receive(:get_response).and_return(response)
        
        result = core.send(:download_umd_content, 'https://example.com/test.js')
        expect(result).to eq('console.log("test");')
      end
    end
  end

  describe 'Package management errors' do
    before do
      allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
      allow(File).to receive(:exist?).and_call_original
    end

    describe '#remove!' do
      it 'raises PackageNotFoundError when package is not installed' do
        allow(File).to receive(:exist?).with('/tmp/test_app/package.json').and_return(true)
        allow(File).to receive(:read).with('/tmp/test_app/package.json').and_return('{"dependencies": {}}')
        
        expect {
          core.remove!('nonexistent-package')
        }.to raise_error(IslandjsRails::PackageNotFoundError)
      end
    end

    describe '#update!' do
      it 'raises PackageNotFoundError when package is not installed' do
        allow(File).to receive(:exist?).with('/tmp/test_app/package.json').and_return(true)
        allow(File).to receive(:read).with('/tmp/test_app/package.json').and_return('{"dependencies": {}}')
        
        expect {
          core.update!('nonexistent-package')
        }.to raise_error(IslandjsRails::PackageNotFoundError)
      end
    end
  end

  describe 'JSON parsing errors' do
    before do
      allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
    end

    it 'handles malformed package.json gracefully' do
      package_json_path = Pathname.new('/tmp/test_app/package.json')
      allow(File).to receive(:exist?).with(package_json_path).and_return(true)
      allow(File).to receive(:read).with(package_json_path).and_return('invalid json')
      
      result = core.send(:package_json)
      expect(result).to be_nil
    end
  end

  describe 'Yarn command errors' do
    before do
      allow(Rails).to receive(:root).and_return(Pathname.new('/tmp/test_app'))
    end

    describe '#yarn_update!' do
      it 'raises YarnError when yarn upgrade fails' do
        allow(Open3).to receive(:capture3).and_return(['', 'yarn error', double(success?: false)])
        
        expect {
          core.send(:yarn_update!, 'react')
        }.to raise_error(IslandjsRails::YarnError, /Failed to update react/)
      end
    end

    describe '#remove_package_via_yarn' do
      it 'raises YarnError when yarn remove fails' do
        allow(Open3).to receive(:capture3).and_return(['', 'yarn error', double(success?: false)])
        
        expect {
          core.send(:remove_package_via_yarn, 'react')
        }.to raise_error(IslandjsRails::YarnError, /Failed to remove react/)
      end
    end
  end
end
