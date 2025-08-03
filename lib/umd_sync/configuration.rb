module UmdSync
  class Configuration
    attr_accessor :package_json_path, :partials_dir, :webpack_config_path, :supported_cdns, :global_name_overrides
    
    def initialize
      @package_json_path = Rails.root.join('package.json')
      @partials_dir = Rails.root.join('app', 'views', 'shared', 'umd')
      @webpack_config_path = Rails.root.join('webpack.config.js')
      @supported_cdns = ['https://unpkg.com', 'https://cdn.jsdelivr.net/npm']
      @global_name_overrides = BUILT_IN_GLOBAL_NAME_OVERRIDES.dup
    end
  end

  # Common UMD path patterns to try for any package
  UMD_PATH_PATTERNS = [
    # Standard UMD patterns
    'umd/{name}.min.js',
    'umd/{name}.production.min.js', 
    'umd/{name}.js',
    'dist/{name}.min.js',
    'dist/{name}.umd.min.js',
    'dist/{name}.umd.js',
    'dist/{name}.js',
    'lib/{name}.min.js',
    'lib/{name}.js',
    '{name}.min.js',
    '{name}.js',
    # Browser-specific builds
    'dist/{name}.browser.min.js',
    'dist/{name}.browser.js',
    'browser/{name}.min.js',
    'browser/{name}.js',
    # Global builds (Vue, etc.)
    'dist/{name}.global.prod.js',
    'dist/{name}.global.min.js',
    'dist/{name}.global.js',
    # IIFE builds (modern packages)
    'lib/index.iife.min.js',
    'dist/index.iife.min.js',
    'index.iife.min.js',
    # Bundle builds
    'dist/bundle.min.js',
    'bundle.min.js'
  ].freeze

  # CDN base URLs to try
  CDN_BASES = [
    'https://unpkg.com',
    'https://cdn.jsdelivr.net/npm'
  ].freeze

  # Built-in global name overrides for popular packages
  # Only includes packages where the npm package name differs from the global variable name
  # If package name == global name, auto-detection will handle it (no override needed)
  BUILT_IN_GLOBAL_NAME_OVERRIDES = {
    # React ecosystem - package names use kebab-case, globals use PascalCase
    'react' => 'React',
    'react-dom' => 'ReactDOM',
    'react-router' => 'ReactRouter',
    'react-router-dom' => 'ReactRouterDOM',
    
    # Utility libraries with symbolic global names
    'lodash' => '_',
    'underscore' => '_',
    'jquery' => '$',
    'zepto' => '$',
    
    # Libraries with different casing or naming conventions
    'date-fns' => 'dateFns',
    'vue' => 'Vue',
    'angular' => 'ng',
    
    # Scoped packages that flatten to different global names
    '@solana/web3.js' => 'solanaWeb3',
    'web3' => 'Web3',
    
    # Packages with dots in name vs camelCase globals
    'chart.js' => 'Chart',
    'plotly.js' => 'Plotly',
    
    # State management with different casing
    'redux' => 'Redux'
  }.freeze

  # Alias for backward compatibility
  GLOBAL_NAME_OVERRIDES = BUILT_IN_GLOBAL_NAME_OVERRIDES
end 