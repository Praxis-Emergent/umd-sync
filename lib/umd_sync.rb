require 'json'
require 'net/http'
require 'uri'
require 'fileutils'
require 'open3'
require 'active_support/core_ext/module/delegation'

require_relative 'umd_sync/version'
require_relative 'umd_sync/configuration'
require_relative 'umd_sync/core'
require_relative 'umd_sync/rails_helpers'
require_relative 'umd_sync/cli'
require_relative 'umd_sync/railtie' if defined?(Rails)

module UmdSync
  class Error < StandardError; end
  class PackageNotFoundError < Error; end
  class VersionMismatchError < Error; end
  class UmdNotFoundError < Error; end
  class YarnError < Error; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    # Delegate main methods to Core
    delegate :init!, :install!, :update!, :remove!, :sync!, :status!, :clean!,
             :package_installed?, :detect_global_name, :version_for,
             :find_working_umd_url, to: :core

    def core
      @core ||= Core.new
    end
  end
end 