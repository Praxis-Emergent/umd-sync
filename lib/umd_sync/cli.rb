require 'thor'

module UmdSync
  class CLI < Thor
    desc "init", "Initialize UmdSync in this Rails project"
    def init
      UmdSync.init!
    end

    desc "install PACKAGE [VERSION]", "Install a UMD package"
    def install(package_name, version = nil)
      UmdSync.install!(package_name, version)
    end

    desc "update PACKAGE [VERSION]", "Update a UMD package"
    def update(package_name, version = nil)
      UmdSync.update!(package_name, version)
    end

    desc "remove PACKAGE", "Remove a UMD package"
    def remove(package_name)
      UmdSync.remove!(package_name)
    end

    desc "sync", "Sync all UMD packages with current package.json"
    def sync
      UmdSync.sync!
    end

    desc "status", "Show status of all UMD packages"
    def status
      UmdSync.status!
    end

    desc "clean", "Clean all UMD partials and reset webpack externals"
    def clean
      UmdSync.clean!
    end

    desc "config", "Show UmdSync configuration"
    def config
      config = UmdSync.configuration
      puts "📊 UmdSync Configuration"
      puts "=" * 40
      puts "Package.json path: #{config.package_json_path}"
      puts "Partials directory: #{config.partials_dir}"
      puts "Webpack config path: #{config.webpack_config_path}"
      puts "Supported CDNs: #{config.supported_cdns.join(', ')}"
      puts "Global name overrides: #{config.global_name_overrides.size} configured"
    end

    desc "version", "Show UmdSync version"
    def version
      puts "UmdSync #{UmdSync::VERSION}"
    end
  end
end 