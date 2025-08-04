require 'pathname'

module IslandjsRails
  class Configuration
    attr_accessor :package_json_path, :partials_dir, :webpack_config_path, :supported_cdns, :global_name_overrides,
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
      @global_name_overrides = {
        # React ecosystem
        'react' => 'React',
        'react-dom' => 'ReactDOM',
        'react-router' => 'ReactRouter',
        'react-router-dom' => 'ReactRouterDOM',
        
        # Utility libraries
        'lodash' => '_',
        'underscore' => '_',
        'jquery' => '$',
        'zepto' => '$',
        'date-fns' => 'dateFns',
        
        # Frameworks
        'vue' => 'Vue',
        'angular' => 'ng',
        
        # Blockchain
        '@solana/web3.js' => 'solanaWeb3',
        'web3' => 'Web3',
        
        # Visualization
        'chart.js' => 'Chart',
        'plotly.js' => 'Plotly',
        
        # State management
        'redux' => 'Redux'
      }
    end

    # Island path patterns for different CDNs
    ISLAND_PATH_PATTERNS = [
      '/umd/{name}.min.js',
      '/umd/{name}.js',
      '/umd/{name}.production.min.js',
      '/umd/{name}.development.js',
      '/dist/umd/{name}.min.js',
      '/dist/umd/{name}.js',
      '/dist/{name}.min.js',
      '/dist/{name}.js',
      '/build/{name}.min.js',
      '/build/{name}.js',
      '/{name}.min.js',
      '/{name}.js'
    ].freeze

    # Scoped package name mappings
    SCOPED_PACKAGE_MAPPINGS = {
      '@solana/web3.js' => 'solana-web3.js',
      '@babel/core' => 'babel-core',
      '@babel/preset-env' => 'babel-preset-env',
      '@babel/preset-react' => 'babel-preset-react'
    }.freeze

    def add_global_name_override(package_name, global_name)
      @global_name_overrides[package_name] = global_name
    end

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
