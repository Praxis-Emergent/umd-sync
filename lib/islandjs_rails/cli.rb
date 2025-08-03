require 'thor'

module IslandjsRails
  class CLI < Thor
    desc "init", "Initialize IslandJS in this Rails project"
    def init
      IslandjsRails.init!
    end

    desc "install PACKAGE_NAME [VERSION]", "Install a JavaScript island package"
    def install(package_name, version = nil)
      IslandjsRails.install!(package_name, version)
    end

    desc "update PACKAGE_NAME [VERSION]", "Update a JavaScript island package"
    def update(package_name, version = nil)
      IslandjsRails.update!(package_name, version)
    end

    desc "remove PACKAGE_NAME", "Remove a JavaScript island package"
    def remove(package_name)
      IslandjsRails.remove!(package_name)
    end

    desc "sync", "Sync all JavaScript island packages with current package.json"
    def sync
      IslandjsRails.sync!
    end

    desc "status", "Show status of all JavaScript island packages"
    def status
      IslandjsRails.status!
    end

    desc "clean", "Clean all island partials and reset webpack externals"
    def clean
      IslandjsRails.clean!
    end

    desc "config", "Show IslandJS configuration"
    def config
      config = IslandjsRails.configuration
      puts "📊 IslandJS Rails Configuration"
      puts "=" * 40
      puts "Package.json path: #{config.package_json_path}"
      puts "Partials directory: #{config.partials_dir}"
      puts "Webpack config path: #{config.webpack_config_path}"
      puts "Supported CDNs: #{config.supported_cdns.join(', ')}"
      puts "Global name overrides: #{config.global_name_overrides.size} configured"
    end

    desc "version", "Show IslandJS Rails version"
    def version
      puts "IslandJS Rails #{IslandjsRails::VERSION}"
    end
  end
end
