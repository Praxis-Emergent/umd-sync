require 'pathname'

module IslandjsRails
  class Configuration
    attr_accessor :package_json_path, :partials_dir, :webpack_config_path, :supported_cdns,
                  :vendor_script_mode, :vendor_order, :vendor_dir, :combined_basename

    def initialize
      @package_json_path = Rails.root.join('package.json')
      @partials_dir = Rails.root.join('app', 'views', 'shared', 'islands')
      @webpack_config_path = Rails.root.join('webpack.config.js')
      @vendor_script_mode = :external_split  # :external_split or :external_combined
      @vendor_order = %w[react react-dom]    # combine order for :external_combined
      @vendor_dir = Rails.root.join('public', 'islands', 'vendor')
      @combined_basename = 'islands-vendor'
      @supported_cdns = [
        'https://unpkg.com',
        'https://cdn.jsdelivr.net/npm'
      ]
    end


    # Scoped package name mappings
    SCOPED_PACKAGE_MAPPINGS = {
      '@solana/web3.js' => 'solana-web3.js',
      '@babel/core' => 'babel-core',
      '@babel/preset-env' => 'babel-preset-env',
      '@babel/preset-react' => 'babel-preset-react'
    }.freeze

    # Vendor file helper methods
    def vendor_manifest_path
      @vendor_dir.join('manifest.json')
    end

    def vendor_partial_path
      @partials_dir.join('_vendor_umd.html.erb')
    end

    def vendor_file_path(package_name, version)
      safe_name = package_name.gsub(/[@\/]/, '_').gsub(/-/, '_')
      @vendor_dir.join("#{safe_name}-#{version}.min.js")
    end

    def combined_vendor_path(hash)
      @vendor_dir.join("#{@combined_basename}-#{hash}.js")
    end
  end
end
