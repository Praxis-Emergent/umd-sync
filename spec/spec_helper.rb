require 'simplecov'

# Start SimpleCov before requiring any application code
SimpleCov.start do
  add_filter '/spec/'
  add_filter '/vendor/'
  
  add_group 'Core', 'lib/islandjs_rails/core.rb'
  add_group 'Rails Integration', ['lib/islandjs_rails/rails_helpers.rb', 'lib/islandjs_rails/railtie.rb']
  add_group 'CLI', 'lib/islandjs_rails/cli.rb'
  add_group 'Configuration', 'lib/islandjs_rails/configuration.rb'
  
  minimum_coverage 85
  minimum_coverage_by_file 30
end

require 'bundler/setup'
require 'islandjs_rails'
require 'vcr'
require 'webmock/rspec'
require 'rails'
require 'action_view'
require 'tempfile'
require 'fileutils'

# VCR configuration for HTTP request stubbing
VCR.configure do |config|
  config.cassette_library_dir = File.expand_path('../fixtures/vcr_cassettes', __FILE__)
  config.hook_into :webmock
  config.configure_rspec_metadata!
  config.allow_http_connections_when_no_cassette = false
  
  # Filter sensitive data
  config.filter_sensitive_data('<FILTERED>') { |interaction|
    interaction.request.headers['Authorization']&.first
  }
  
  # Default cassette options
  config.default_cassette_options = {
    record: :once,
    match_requests_on: [:method, :uri, :body]
  }
end

# Rails test environment setup
ENV['RAILS_ENV'] = 'test'

# Create a minimal Rails application for testing
class TestApp < Rails::Application
  config.eager_load = false
  config.active_support.deprecation = :log
  config.log_level = :fatal
  config.root = File.expand_path('../../tmp', __FILE__)
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Object`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Clean up temporary files after each test
  config.before(:each) do
    @temp_dirs = []
    @original_rails_root = Rails.root if defined?(Rails)
  end

  config.after(:each) do
    @temp_dirs.each do |dir|
      FileUtils.rm_rf(dir) if Dir.exist?(dir)
    end
    
    # Reset IslandjsRails configuration
    IslandjsRails.instance_variable_set(:@configuration, nil)
    IslandjsRails.instance_variable_set(:@core, nil)
  end
  
  config.after(:suite) do
    # Clean up any accidentally created app/ directory in project root after all tests
    project_root = File.expand_path('../..', __FILE__)
    app_dir = File.join(project_root, 'app')
    
    if Dir.exist?(app_dir)
      # This gem should not have an app/ directory in its root
      FileUtils.rm_rf(app_dir)
    end
  end

  # Helper methods for tests
  config.include Module.new {
    def create_temp_dir
      dir = Dir.mktmpdir
      @temp_dirs << dir
      dir
    end

    def create_temp_package_json(dir, dependencies = {})
      package_json = {
        'name' => 'test-app',
        'version' => '1.0.0',
        'dependencies' => dependencies
      }
      File.write(File.join(dir, 'package.json'), JSON.pretty_generate(package_json))
    end

    def create_temp_webpack_config(dir)
      webpack_content = <<~JS
        module.exports = {
          externals: {
            // Existing externals
          }
        };
      JS
      File.write(File.join(dir, 'webpack.config.js'), webpack_content)
    end

    def mock_rails_root(path)
      allow(Rails).to receive(:root).and_return(Pathname.new(path))
    end

    def with_configuration(**options, &block)
      IslandjsRails.configure do |config|
        options.each { |key, value| config.send("#{key}=", value) }
      end
      block.call
    end
  }
end 