require_relative "islandjs_rails/version"
require_relative "islandjs_rails/configuration"
require_relative "islandjs_rails/core"
require_relative "islandjs_rails/cli"

# Conditionally require Rails-specific components
if defined?(Rails)
  require_relative "islandjs_rails/railtie"
  require_relative "islandjs_rails/rails_helpers"
end

module IslandjsRails
  # Custom error classes
  class Error < StandardError; end
  class YarnError < Error; end
  class IslandNotFoundError < Error; end

  class << self
    # Configuration management
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Core instance management
    def core
      @core ||= Core.new
    end

    # Delegate common methods to core
    def init!
      core.init!
    end

    def install!(package_name, version = nil)
      core.install!(package_name, version)
    end

    def update!(package_name, version = nil)
      core.update!(package_name, version)
    end

    def remove!(package_name)
      core.remove!(package_name)
    end

    def sync!
      core.sync!
    end

    def status!
      core.status!
    end

    def clean!
      core.clean!
    end

    def package_installed?(package_name)
      core.package_installed?(package_name)
    end

    def version_for(library_name)
      core.version_for(library_name)
    end

    def detect_global_name(package_name)
      core.detect_global_name(package_name)
    end

    def find_working_island_url(package_name, version)
      core.find_working_island_url(package_name, version)
    end
  end
end
