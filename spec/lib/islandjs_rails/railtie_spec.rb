require_relative '../../spec_helper'
require 'islandjs_rails/railtie'

RSpec.describe IslandjsRails::Railtie do
  describe 'railtie configuration' do
    it 'has the correct railtie name' do
      expect(IslandjsRails::Railtie.railtie_name).to eq("islandjs_rails")
    end

    it 'inherits from Rails::Railtie' do
      expect(IslandjsRails::Railtie.superclass).to eq(Rails::Railtie)
    end
  end

  describe 'helper integration' do
    it 'includes IslandjsRails::RailsHelpers in ActionView' do
      initializer = IslandjsRails::Railtie.initializers.find { |i| i.name == 'islandjs_rails.view_helpers' }
      expect(initializer).to be_present
    end
  end

  describe 'development warnings initializer' do
    it 'creates the development warnings initializer' do
      initializer = IslandjsRails::Railtie.initializers.find { |i| i.name == 'islandjs_rails.development_warnings' }
      expect(initializer).to be_present
    end

    it 'sets the initializer to run after load_config_initializers' do
      initializer = IslandjsRails::Railtie.initializers.find { |i| i.name == 'islandjs_rails.development_warnings' }
      expect(initializer.after).to eq(:load_config_initializers)
    end

    it 'defines a block for the initializer' do
      initializer = IslandjsRails::Railtie.initializers.find { |i| i.name == 'islandjs_rails.development_warnings' }
      expect(initializer.block).to be_present
    end
  end

  describe 'rake tasks loading' do
    it 'defines rake_tasks block' do
      # This verifies that the railtie has the rake_tasks configuration
      expect(IslandjsRails::Railtie.rake_tasks).to be_present
    end
  end

  describe 'initializers' do
    it 'has initializers defined' do
      expect(IslandjsRails::Railtie.initializers.count).to eq(6)
    end

    it 'defines helpers initializer' do
      helpers_init = IslandjsRails::Railtie.initializers.find { |i| i.name == 'islandjs_rails.view_helpers' }
      expect(helpers_init).to be_present
    end

    it 'defines development warnings initializer' do
      warnings_init = IslandjsRails::Railtie.initializers.find { |i| i.name == 'islandjs_rails.development_warnings' }
      expect(warnings_init).to be_present
    end
  end
end 