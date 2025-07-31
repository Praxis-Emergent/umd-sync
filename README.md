# UmdSync

[![Test Coverage](https://img.shields.io/badge/coverage-89.09%25-brightgreen.svg)](coverage/index.html)
[![RSpec Tests](https://img.shields.io/badge/tests-162%20passing-brightgreen.svg)](spec/)
[![Rails 8 Ready](https://img.shields.io/badge/Rails%208-Ready-brightgreen.svg)](#rails-8-ready)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-red.svg)](https://www.ruby-lang.org/)

**Simplified UMD dependency management for Rails applications.**

UmdSync is a Rails gem that automates UMD (Universal Module Definition) dependency management. Instead of complex webpack configurations for external libraries, UmdSync downloads UMD builds from CDNs and integrates them into your Rails application using ERB partials.

ESM might be "the future", but UMD is "the forever" because it just works everywhere without fuss.

## Why UmdSync?

### Perfect for Rails 8
UmdSync aligns perfectly with **Rails 8's philosophy** of simplicity and convention over configuration:

- **Asset Pipeline Simplification**: Rails 8 streamlined assets - UMD Sync fits seamlessly
- **Zero Webpack Complexity**: No complex bundler configs, just modern JavaScript  
- **Hotwire + React Islands**: The sweet spot for Rails 8 frontend development
- **Fast Development & Deployment**: Instant builds, no library rebundling

### The Problem UmdSync Solves
Modern Rails developers face a painful choice:
- **Bundle everything**: Massive webpack configs, slow builds, bundle bloat
- **Skip modern JS**: Miss out on React, Vue, and popular npm packages with UMD builds

**Important Note:** UmdSync works with packages that ship UMD builds. Many popular packages (React, Vue, Lodash, D3, Chart.js) have UMD builds, but modern packages like @tanstack/query, Zustand, and Emotion do not. React 19+ removed UMD builds entirely. Future versions may support local UMD generation for some packages.

### The UmdSync Solution
```bash
# Instead of complex webpack configuration:
rails umd_sync:install[react]
rails umd_sync:install[lodash]
rails umd_sync:install[vue]
```

**Result**: Zero webpack configuration, instant builds, access to hundreds of UMD packages.

## Rails 8 Ready

✅ **Tested against Rails 8**  
✅ **Compatible with Rails 8 asset pipeline**  
✅ **Optimized for Hotwire/Turbo workflows**  
✅ **Zero-config React islands**  
✅ **Backward compatible with Rails 7+**

## Core Features

- **Convention over Configuration** - Works with sensible defaults
- **Package.json Integration** - Syncs with your existing package management
- **CDN Downloads** - Fetches UMD builds from unpkg.com and jsdelivr.net
- **Rails Integration** - Uses ERB partials for seamless integration
- **Automatic Global Detection** - Converts package names to global variables
- **Webpack Externals** - Updates webpack config to prevent duplicate bundling
- **Flexible Architecture** - Compose and namespace libraries as needed

## Philosophy

UmdSync follows the Rails philosophy:
- **Convention over Configuration**: Smart defaults, minimal setup
- **Don't Repeat Yourself**: One command replaces complex configurations
- **Optimize for Programmer Happiness**: Simple, powerful, intuitive

## Quick Start

### Installation

```ruby
# Add to your Gemfile
gem 'umd_sync'
```

```bash
bundle install
rails umd_sync:init
```

### Install React
```bash
rails umd_sync:install[react]
rails umd_sync:install[react-dom]
```

### Add to your layout
```erb
<!-- app/views/layouts/application.html.erb -->
<head>
  <%= umd_partials %>
  <%= umd_bundle_script %>
</head>
```

### Render React Components
```erb
<!-- In any view -->
<%= react_component('DashboardApp', { userId: current_user.id }) %>
```

### Write Modern JSX
```jsx
// jsx/components/DashboardApp.jsx
import React from 'react';

function DashboardApp({ userId }) {
  return <div>Welcome user {userId}!</div>;
}

window.umd_sync = { DashboardApp };
```

## CLI Commands

### 📦 Package Management

#### Rails Tasks
```bash
# Initialize UmdSync in your project
rails umd_sync:init

# Install packages (adds to package.json + creates UMD partial)
rails umd_sync:install[react]
rails umd_sync:install[react,18.3.1]        # With specific version
rails umd_sync:install[lodash]

# Update packages (updates package.json + refreshes UMD partial)
rails umd_sync:update[react]
rails umd_sync:update[react,18.3.1]         # To specific version

# Remove packages (removes from package.json + deletes UMD partial)
rails umd_sync:remove[react]
rails umd_sync:remove[lodash]

# Sync all packages with current package.json
rails umd_sync:sync

# Show status of all UMD packages
rails umd_sync:status

# Clean all UMD files (removes ALL partials)
rails umd_sync:clean

# Show configuration
rails umd_sync:config
```

#### Standalone CLI
```bash
# If you have the gem installed globally
umd-sync init
umd-sync install react
umd-sync install react 18.3.1      # With version (space-separated)
umd-sync update react
umd-sync update react 18.3.1       # To specific version
umd-sync remove react              # Remove package
umd-sync sync
umd-sync status
umd-sync clean
umd-sync config
umd-sync version
```

### ⚡ Quick Reference

| Command | What it does | Example |
|---------|--------------|---------|
| `install` | Adds package via yarn + downloads UMD + creates partial | `rails umd_sync:install[react]` |
| `update` | Updates package version + refreshes UMD | `rails umd_sync:update[react,18.3.1]` |
| `remove` | Removes package via yarn + deletes partial | `rails umd_sync:remove[react]` |
| `sync` | Re-downloads UMDs for all packages in package.json | `rails umd_sync:sync` |
| `status` | Shows which packages have UMD partials | `rails umd_sync:status` |
| `clean` | Removes ALL UMD partials (destructive!) | `rails umd_sync:clean` |

### Configuration

```ruby
# config/initializers/umd_sync.rb
UmdSync.configure do |config|
  config.partials_dir = Rails.root.join('app/views/shared/umd')
  config.webpack_config_path = Rails.root.join('webpack.config.js')
end
```

## Rails Integration

### Helpers

#### `umd_partials`
Renders all UMD library scripts for installed packages.

```erb
<%= umd_partials %>
```

#### `react_component(name, props, options)`
Renders a React component with Turbo-compatible lifecycle.

```erb
<%= react_component('UserProfile', { 
  userId: current_user.id,
  theme: 'dark' 
}, {
  container_id: 'profile-widget',
  namespace: 'window.MyApp'
}) %>
```

#### `umd_complete`
One-liner that includes all UMD partials and your webpack bundle.

```erb
<%= umd_complete %>
```

## Advanced Usage

### Custom Global Names

```ruby
# Override automatic global name detection
UmdSync.configure do |config|
  config.global_name_overrides = {
    '@mui/material' => 'MaterialUI',
    'react-router-dom' => 'ReactRouterDOM'
  }
end
```

### Composable Architecture

```javascript
// Create your own namespace
window.MyApp = {
  React: window.React,
  UI: window.MaterialUI,
  Utils: window._,
  Charts: window.Chart
};

// Use in components
const { React, UI, Utils } = window.MyApp;
```

### Webpack Integration

UmdSync automatically updates your webpack externals:

```javascript
// webpack.config.js (auto-generated)
module.exports = {
  externals: {
    'react': 'React',
    'lodash': '_',
    '@mui/material': 'MaterialUI'
  }
};
```

## Ruby API Reference

### Core Methods (for programmatic use)

```ruby
# Initialize UmdSync in project
UmdSync.init!

# Install a package and create partial
UmdSync.install!('react', '18.3.1')

# Update an existing package
UmdSync.update!('react', '18.3.1')

# Remove a package (from package.json + delete partial)
UmdSync.remove!('react')

# Sync all packages
UmdSync.sync!

# Show status
UmdSync.status!

# Clean all partials and reset webpack externals
UmdSync.clean!

# Check what packages are installed
UmdSync.package_installed?('react')

# Get version for a package
UmdSync.version_for('react')
```

### Configuration Options

```ruby
UmdSync.configure do |config|
  # Directory for UMD partials (default: app/views/shared/umd)
  config.partials_dir = Rails.root.join('app/views/shared/umd')
  
  # Path to webpack config (default: webpack.config.js)
  config.webpack_config_path = Rails.root.join('webpack.config.js')
  
  # Path to package.json (default: package.json)
  config.package_json_path = Rails.root.join('package.json')
  
  # Custom global name mappings
  config.global_name_overrides = {
    'package-name' => 'GlobalName'
  }
end
```

## Real-World Examples

### React Dashboard Component

```bash
# Install dependencies
rails umd_sync:install[react]
rails umd_sync:install[react-dom]  
rails umd_sync:install[chart.js]
```

```erb
<!-- app/views/dashboard/show.html.erb -->
<%= render 'shared/umd/react' %>
<%= render 'shared/umd/react_dom' %>
<%= render 'shared/umd/chart_js' %>

<div id="dashboard-root"></div>

<script>
  const Dashboard = () => {
    const [data, setData] = React.useState([]);
    
    React.useEffect(() => {
      // Fetch dashboard data
      fetch('/api/dashboard')
        .then(res => res.json())
        .then(setData);
    }, []);
    
    return React.createElement('div', null, 
      React.createElement('h1', null, 'Dashboard'),
      // Chart component here
    );
  };
  
  ReactDOM.render(
    React.createElement(Dashboard),
    document.getElementById('dashboard-root')
  );
</script>
```

### Turbo + React Integration

```javascript
// Perfect for Rails + Turbo apps
document.addEventListener('turbo:load', () => {
  const container = document.getElementById('react-component');
  if (container && !container.hasChildNodes()) {
    ReactDOM.render(
      React.createElement(MyComponent, {
        data: JSON.parse(container.dataset.props)
      }),
      container
    );
  }
});

document.addEventListener('turbo:before-cache', () => {
  // Cleanup React components before Turbo caches
  document.querySelectorAll('[data-react-component]').forEach(el => {
    ReactDOM.unmountComponentAtNode(el);
  });
});
```

## Troubleshooting

### Common Issues

**Package not found on CDN:**
```ruby
# Some packages don't publish UMD builds
# Check unpkg.com/package-name/ for available files
# Consider using a different package or requesting UMD support
```

**Global name conflicts:**
```ruby
# Override automatic detection
UmdSync.configure do |config|
  config.global_name_overrides = {
    'conflicting-package' => 'UniqueGlobalName'
  }
end
```

**Webpack externals not updating:**
```bash
# Sync to update externals
rails umd_sync:sync

# Or clean and reinstall
rails umd_sync:clean
rails umd_sync:install[react]
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Run the tests (`bundle exec rake test`)
4. Commit your changes (`git commit -am 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## Testing

```bash
# Run all tests
bundle exec rspec

# Run specific test file
bundle exec rspec spec/lib/umd_sync/core_spec.rb

# Run with coverage report
bundle exec rspec --format documentation
```

## License

MIT License - see LICENSE file for details.

## Structure

```
lib/umd_sync/
├── spec/
│   ├── spec_helper.rb                    # Test setup and mocking
│   ├── lib/
│   │   ├── umd_sync_spec.rb             # Main module tests
│   │   └── umd_sync/
│   │       ├── core_spec.rb             # Core functionality tests
│   │       ├── rails_helpers_spec.rb    # Rails helpers tests
│   │       ├── configuration_spec.rb    # Configuration tests
│   │       ├── cli_spec.rb             # CLI tests
│   │       ├── tasks_spec.rb           # Rake tasks tests
│   │       ├── railtie_spec.rb         # Rails integration tests
│   │       └── rails8_integration_spec.rb # Rails 8 specific tests
│   ├── fixtures/                        # Test fixtures
│   └── support/                         # Test support files
├── coverage/                            # SimpleCov coverage reports
├── Gemfile                              # Test dependencies
├── Rakefile                             # Test runner configuration
└── README.md                            # This file
```

## Running Tests

### From the gem directory:

```bash
cd lib/umd_sync
bundle install
bundle exec rspec
```

### Individual test files:

```bash
bundle exec rspec spec/lib/umd_sync/core_spec.rb
bundle exec rspec spec/lib/umd_sync/rails_helpers_spec.rb
bundle exec rspec spec/lib/umd_sync/configuration_spec.rb
```

### Coverage Reports:

```bash
# View coverage in terminal
bundle exec rspec

# Open coverage report in browser
open coverage/index.html
```

## Test Features

### Complete Isolation
- **No external dependencies**: All CDN calls are mocked with WebMock
- **Temporary file system**: Each test creates its own Rails-like directory structure
- **Rails mocking**: Full Rails and ActiveSupport environment simulation
- **Clean state**: Each test starts with a fresh configuration

### Comprehensive Coverage
- **89.1% line coverage**: High test coverage across all modules
- **Core functionality**: UMD detection, partial generation, webpack externals
- **Rails integration**: View helpers, React component mounting, Turbo compatibility
- **Configuration**: All configuration options and global name overrides
- **Error handling**: Network failures, missing packages, invalid configurations
- **CLI simulation**: All major UmdSync operations and rake tasks

### Realistic Testing
- **Mock Rails app**: Complete package.json, webpack.config.js, directory structure
- **CDN simulation**: Success and failure scenarios for UMD discovery with VCR
- **File operations**: Actual file creation and modification (in temp directories)
- **Rails helpers**: Full ActionView integration testing

## Test Philosophy

This test suite follows these principles:

1. **Fast**: No real network calls, minimal file I/O
2. **Isolated**: No dependencies on external services or host environment
3. **Comprehensive**: Tests all public APIs and error conditions
4. **Maintainable**: Clear test structure and helper methods
5. **Portable**: Self-contained with the gem

## Dependencies

- **rspec**: Modern Ruby testing framework
- **webmock**: HTTP request stubbing for CDN calls
- **vcr**: HTTP interaction recording and playback
- **simplecov**: Code coverage analysis
- **rake**: Test runner

All dependencies are isolated to this test suite and won't affect applications using the gem.

## Adding New Tests

When adding new UmdSync functionality:

1. Add tests to the appropriate test file
2. Use the provided test helpers for consistency
3. Mock external dependencies (CDN calls, file system operations)
4. Test both success and failure scenarios
5. Ensure tests are isolated and don't affect each other

## Continuous Integration

This test suite is designed to work with any CI system:

```yaml
# Example GitHub Actions
- name: Run UmdSync tests
  run: |
    cd lib/umd_sync
    bundle install
    bundle exec rake test
```

## Roadmap & Future Features

### Planned for v0.2.0
- **Server-Side Rendering (SSR)**: Pre-render React components on the server for faster initial page loads and better SEO
- **Component Caching**: Intelligent caching of rendered components with invalidation strategies
- **Hot Reloading**: Development mode hot reloading for React components
- **TypeScript Support**: First-class TypeScript support for UMD packages

### Planned for v0.3.0 - Local UMD Generation
- **Generate Missing UMDs**: Automatically create UMD builds for packages that don't ship them
- **Smart Build Detection**: Analyze package structure to generate optimal UMD configurations
- **Local-Only Approach**: No external dependencies - everything generated and cached locally
- **Community Build Recipes**: Share proven build configurations via GitHub, not file storage
- **Zero-Config Generation**: `UmdSync.install_package!('@tanstack/query', generate: true)` just works
- **Target Coverage**: Support 30-40% of packages that lack UMD builds (focusing on simple, commonly-used libraries)

### SSR Preview
```ruby
# Coming soon in v0.2.0:
<%= react_component_ssr('DashboardApp', { userId: current_user.id }) %>
# Renders on server, hydrates on client automatically
```

### Local UMD Generation Preview
```ruby
# Coming soon in v0.3.0:
UmdSync.install_package!('@tanstack/query', generate: true)
UmdSync.install_package!('zustand', generate: true)
UmdSync.install_package!('@emotion/react', generate: true)
# Locally generates UMD builds for 30-40% of packages missing them
# No external services, no infrastructure costs, just works!
```

### Long-term Vision
- **Multi-framework Support**: Vue, Svelte, and other frameworks
- **Build-time Optimization**: Optional build-time bundling for production
- **Edge Computing**: Cloudflare Workers and similar platform support

---

## Rails 8 Integration Benefits

### 🚀 **Perfect for Rails 8 Philosophy**
- **Convention over Configuration**: Install React in one command
- **The Rails Way**: Simple, opinionated, productive
- **Modern Without Complexity**: React islands, not SPAs

### ⚡ **Performance Optimized**
- **Instant Builds**: No bundling external libraries
- **Small Bundles**: Only your app code gets bundled
- **Fast Deploys**: CDN libraries cache globally

### 🎯 **Developer Experience**
- **Zero Webpack Expertise**: Rails developers stay in Rails
- **Turbo Compatible**: Seamless navigation and caching
- **Progressive Enhancement**: Start with Hotwire, add React islands

---

**Ready to revolutionize Rails 8 frontend development?** UmdSync makes modern JavaScript simple again.
