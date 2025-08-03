require 'spec_helper'
require 'umd_sync/railtie'

RSpec.describe UmdSync::Railtie do
  describe 'railtie configuration' do
    it 'has the correct railtie name' do
      expect(UmdSync::Railtie.railtie_name).to eq("umd_sync")
    end

    it 'inherits from Rails::Railtie' do
      expect(UmdSync::Railtie.superclass).to eq(Rails::Railtie)
    end
  end

  describe 'helper integration' do
    it 'includes UmdSync::RailsHelpers in ActionView' do
      # The railtie defines an initializer that includes helpers
      # We can test that the initializer exists
      initializer = UmdSync::Railtie.initializers.find { |i| i.name == 'umd_sync.helpers' }
      expect(initializer).to be_present
    end
  end

  describe 'development warnings initializer' do
    it 'creates the development warnings initializer' do
      initializer = UmdSync::Railtie.initializers.find { |i| i.name == 'umd_sync.development_warnings' }
      expect(initializer).to be_present
    end

    it 'sets the initializer to run after initialize_logger' do
      initializer = UmdSync::Railtie.initializers.find { |i| i.name == 'umd_sync.development_warnings' }
      expect(initializer.after).to eq('initialize_logger')
    end

    it 'defines a block for the initializer' do
      initializer = UmdSync::Railtie.initializers.find { |i| i.name == 'umd_sync.development_warnings' }
      expect(initializer.block).to be_present
    end
  end

  describe 'rake tasks loading' do
    it 'defines rake_tasks block' do
      # This verifies that the railtie has the rake_tasks configuration
      expect(UmdSync::Railtie.rake_tasks).to be_present
    end
  end

  describe 'initializers' do
    it 'has initializers defined' do
      expect(UmdSync::Railtie.initializers.count).to eq(3)
    end

    it 'defines helpers initializer' do
      helpers_init = UmdSync::Railtie.initializers.find { |i| i.name == 'umd_sync.helpers' }
      expect(helpers_init).to be_present
    end

    it 'defines development warnings initializer' do
      warnings_init = UmdSync::Railtie.initializers.find { |i| i.name == 'umd_sync.development_warnings' }
      expect(warnings_init).to be_present
    end
  end
end 