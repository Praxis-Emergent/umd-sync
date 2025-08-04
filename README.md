# IslandJS Rails

[![Test Coverage](https://img.shields.io/badge/coverage-89.09%25-brightgreen.svg)](coverage/index.html)
[![RSpec Tests](https://img.shields.io/badge/tests-162%20passing-brightgreen.svg)](spec/)
[![Rails 8 Ready](https://img.shields.io/badge/Rails%208-Ready-brightgreen.svg)](#rails-8-ready)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-red.svg)](https://www.ruby-lang.org/)

**Simplified UMD dependency management for Rails applications with zero webpack complexity**

IslandJS Rails enables React, Vue, and other JavaScript islands in Rails apps by loading UMD libraries from CDNs. No complex webpack configurations, no bundle bloat - just clean, fast JavaScript integration that works with Rails' asset pipeline.

ESM might be "the future", but UMD is "the forever" because it just works everywhere without fuss.

## Why IslandJS Rails?

### Perfect for Rails 8
IslandJS Rails aligns perfectly with **Rails 8's philosophy** of simplicity and convention over configuration:

- **Asset Pipeline Simplification**: Rails 8 streamlined assets - IslandJS Rails fits seamlessly 
- **Hotwire + React Islands**: The sweet spot for Rails 8 frontend development
- **Fast Development & Deployment**: Instant builds, no library rebundling

### The Problem IslandJS Rails Solves
Modern Rails developers face a painful choice:
- **Bundle everything**: Massive webpack configs, slow builds, bundle bloat
- **Skip modern JS**: Miss out on React, Vue, and popular npm packages with UMD builds

**Important Note:** IslandJS Rails works with packages that ship UMD builds. Many popular packages (React, Vue, Lodash, D3, Chart.js) have UMD builds, but modern packages like @tanstack/query, Zustand, and Emotion do not. React 19+ removed UMD builds entirely. Future versions may support local UMD generation for some packages.

### The IslandJS Rails Solution
```bash
# Instead of complex webpack configuration:
rails "islandjs:install[react]"
rails "islandjs:install[lodash]"
rails "islandjs:install[vue]"
```

**Result**: Zero webpack configuration, instant builds, access to hundreds of UMD packages.

## Rails 8 Ready

✅ **Tested against Rails 8**  
✅ **Compatible with Rails 8 asset pipeline**  
✅ **Optimized for Hotwire/Turbo workflows**  
✅ **Zero-config React islands**

## Core Features

- **Convention over Configuration** - Works with sensible defaults
- **Package.json Integration** - Syncs with your existing package management
- **CDN Downloads** - Fetches UMD builds from unpkg.com and jsdelivr.net
- **Rails Integration** - Uses ERB partials for seamless integration
- **Automatic Global Detection** - Converts package names to global variables
- **Webpack Externals** - Updates webpack config to prevent duplicate bundling
- **Flexible Architecture** - Compose and namespace libraries as needed

## Philosophy

IslandJS Rails follows the Rails philosophy:
- **Convention over Configuration**: Smart defaults, minimal setup
- **Don't Repeat Yourself**: One command replaces complex configurations
- **Optimize for Programmer Happiness**: Simple, powerful, intuitive

## Quick Start

### Installation

```ruby
# Add to your Gemfile
gem 'islandjs-rails'
```

```bash
bundle install
rails islandjs:init
```

### Install React
```bash
rails "islandjs:install[react,18.3.1]"
rails "islandjs:install[react-dom,18.3.1]"
```

### Render React Components
```erb
<!-- In any view -->
<%= react_component('DashboardApp', { userId: current_user.id }) %>
```

> 💡 **Turbo Cache Compatible**: React components automatically persist state across Turbo navigation! See [Turbo Cache Integration](#turbo-cache-integration) for details.

### Write Modern JSX
```jsx
// jsx/components/DashboardApp.jsx
import React from 'react';

function DashboardApp({ userId }) {
  return <div>Welcome user {userId}!</div>;
}
```

## CLI Commands

### 📦 Package Management

#### Rails Tasks
```bash
# Initialize IslandJS Rails in your project
rails islandjs:init

# Install packages (adds to package.json + creates UMD partial)
rails "islandjs:install[react]"
rails "islandjs:install[react,18.3.1]"       # With specific version
rails "islandjs:install[lodash]"

# Update packages (updates package.json + refreshes UMD partial)
rails "islandjs:update[react]"
rails "islandjs:update[react,18.3.1]"       # To specific version

# Remove packages (removes from package.json + deletes UMD partial)
rails "islandjs:remove[react]"
rails "islandjs:remove[lodash]"

# Sync all packages with current package.json
rails islandjs:sync

# Show status of all UMD packages
rails islandjs:status

# Clean all UMD files (removes ALL partials)
rails islandjs:clean

# Show configuration
rails islandjs:config
```

## 📦 Working with Scoped Packages

### What are Scoped Packages?

Scoped packages are npm packages that belong to a namespace, prefixed with `@`. Examples include:
- `@solana/web3.js`
- `@mui/material` 
- `@tanstack/react-query`
- `@emotion/react`

### Installation Syntax

When installing scoped packages, you **must** include the full package name with the `@` symbol:

```bash
# ✅ Correct - Full scoped package name
rails "islandjs:install[@solana/web3.js,1.98.2]"
rails "islandjs:install[@mui/material,5.14.1]"
rails "islandjs:install[@emotion/react,11.11.1]"

# ❌ Incorrect - Missing .js suffix
rails "islandjs:install[@solana/web3,1.98.2]"

# ❌ Incorrect - Missing scope
rails "islandjs:install[web3.js,1.98.2]"
```

### Shell Escaping

The `@` symbol is handled automatically by Rails task syntax when using double quotes. No additional escaping is needed:

```bash
# ✅ Works perfectly
rails "islandjs:install[@solana/web3.js]"

# ✅ Also works (with version)
rails "islandjs:install[@solana/web3.js,1.98.2]"

# ⚠️ May not work in some shells without quotes
rails islandjs:install[@solana/web3.js]  # Avoid this
```

### Global Name Detection

IslandJS Rails automatically converts scoped package names to valid JavaScript global names:

```ruby
# Automatic conversions:
'@solana/web3.js'     => 'solanaWeb3'     # Scope removed, camelCase
'@mui/material'       => 'muiMaterial'    # Scope removed, camelCase  
'@emotion/react'      => 'emotionReact'   # Scope removed, camelCase
'@tanstack/query'     => 'tanstackQuery'  # Scope removed, camelCase
```

### Custom Global Names

You can override the automatic global name detection for scoped packages:

```ruby
# config/initializers/islandjs.rb
IslandJS Rails.configure do |config|
  config.global_name_overrides = {
    '@solana/web3.js' => 'solanaWeb3',      # Already built-in
    '@mui/material' => 'MaterialUI',        # Custom override
    '@emotion/react' => 'EmotionReact',     # Custom override
    '@tanstack/react-query' => 'ReactQuery' # Custom override
  }
end
```

### Usage in Components

Once installed, scoped packages work exactly like regular packages:

```jsx
// jsx/components/SolanaComponent.jsx
import { Connection, PublicKey } from '@solana/web3.js';
import React from 'react';

function SolanaComponent() {
  const connection = new Connection('https://api.devnet.solana.com');
  
  return (
    <div>
      <h2>Solana Integration</h2>
      <p>Connected to: {connection.rpcEndpoint}</p>
    </div>
  );
}

export default SolanaComponent;
```

### Webpack Externals

IslandJS Rails automatically configures webpack externals for scoped packages:

```javascript
// webpack.config.js (auto-generated)
module.exports = {
  externals: {
    // IslandJS Rails managed externals - do not edit manually
    "@solana/web3.js": "solanaWeb3",
    "@mui/material": "muiMaterial",
    "react": "React",
    "react-dom": "ReactDOM"
  },
  // ... rest of config
};
```

### Common Scoped Packages

Here are popular scoped packages that work well with IslandJS Rails:

| Package | Command | Global Name | Use Case |
|---------|---------|-------------|----------|
| `@solana/web3.js` | `rails "islandjs:install[@solana/web3.js]"` | `solanaWeb3` | Solana blockchain |
| `@mui/material` | `rails "islandjs:install[@mui/material]"` | `muiMaterial` | Material UI components |
| `@emotion/react` | `rails "islandjs:install[@emotion/react]"` | `emotionReact` | CSS-in-JS styling |

### Troubleshooting Scoped Packages

**Issue: Package not found**
```bash
# Check the exact package name on npm
npm view @solana/web3.js

# Ensure you're using the full name
rails "islandjs:install[@solana/web3.js]"  # ✅ Correct
rails "islandjs:install[@solana/web3]"     # ❌ Wrong
```

**Issue: Global name conflicts**
```ruby
# Override in configuration
IslandJS Rails.configure do |config|
  config.global_name_overrides = {
    '@conflicting/package' => 'UniqueGlobalName'
  }
end
```

**Issue: UMD not available**
```bash
# Some scoped packages don't ship UMD builds
# Check package documentation or try alternatives
# Future IslandJS Rails versions will support local UMD generation
```

### ⚡ Quick Reference

| Command | What it does | Example |
|---------|--------------|---------|
| `install` | Adds package via yarn + downloads UMD + creates partial | `rails islandjs:install[react]` |
| `update` | Updates package version + refreshes UMD | `rails islandjs:update[react,18.3.1]` |
| `remove` | Removes package via yarn + deletes partial | `rails islandjs:remove[react]` |
| `sync` | Re-downloads UMDs for all packages in package.json | `rails islandjs:sync` |
| `status` | Shows which packages have UMD partials | `rails islandjs:status` |
| `clean` | Removes ALL UMD partials (destructive!) | `rails islandjs:clean` |

### Configuration

```ruby
# config/initializers/islandjs.rb
IslandJS Rails.configure do |config|
  config.partials_dir = Rails.root.join('app/views/shared/umd')
  config.webpack_config_path = Rails.root.join('webpack.config.js')
end
```

## Rails Integration

### Helpers

#### `islands`
Single helper that includes all UMD partials and your webpack bundle.

```erb
<%= islands %>
```

#### `react_component(name, props, options)`
Renders a React component with Turbo-compatible lifecycle.

```erb
<%= react_component('UserProfile', { 
  userId: current_user.id,
  theme: 'dark' 
}, {
  container_id: 'profile-widget',
  namespace: 'window.islandjsRailsApp'
}) %>
```

## Turbo Cache Integration

IslandJS Rails includes **built-in Turbo cache compatibility** for React components, ensuring state persists seamlessly across navigation.

### How It Works

The `react_component` helper automatically:
1. **Stores initial props** as JSON in `data-initial-state` attributes
2. **Generates unique container IDs** for each component instance  
3. **Passes only the container ID** to the React component

This allows React components to persist state changes** back to the data attribute before turbo caches the page.

### Example: Turbo-Compatible Component

See the complete working example: [`HelloWorld.jsx`](app/javascript/islands/components/HelloWorld.jsx)

```jsx
import React, { useState, useEffect } from 'react';
import { getInitialState, useTurboCache } from '../utils/turbo.js';

const HelloWorld = ({ containerId }) => {
  // Read initial state from data-initial-state attribute
  const initialState = getInitialState(containerId);
  
  const [count, setCount] = useState(initialState.count || 0);
  const [message, setMessage] = useState(initialState.message || "Hello!");

  // ensures persists state across Turbo navigation
  useEffect(() => {
    const cleanup = useTurboCache(containerId, { count, message }, true);
    return cleanup;
  }, [containerId, count, message]);

  return (
    <div>
      <p>{message}</p>
      <button onClick={() => setCount(count + 1)}>
        Clicked {count} times
      </button>
    </div>
  );
};
```

### Usage in Views

```erb
<!-- In any Rails view -->
<%= react_component('HelloWorld', { 
  message: 'Hello from Rails!', 
  count: 5 
}) %>
```

### Live Demo

See the complete demo: [`react.html.erb`](app/views/islandjs_demo/react.html.erb)

The demo shows:
- ✅ **State persistence** across Turbo navigation
- ✅ **Automatic state restoration** when navigating back
- ✅ **Zero configuration** - works out of the box
- ✅ **Compatible with Turbo Drive** and all Hotwire features

### Turbo Utility Functions

IslandJS Rails provides utility functions for Turbo compatibility:

```javascript
// Get initial state from container's data attribute
const initialState = getInitialState(containerId);

// Set up automatic state persistence
const cleanup = useTurboCache(containerId, currentState, autoRestore);

// Manually persist state (if needed)
persistState(containerId, stateObject);
```

### Benefits

- **🔄 Seamless Navigation**: State survives Turbo page transitions
- **⚡ Zero Setup**: Works automatically with `react_component` helper  
- **🎯 Rails-Native**: Designed specifically for Rails + Turbo workflows
- **🏝️ Island Architecture**: Each component manages its own state independently

## Advanced Usage

### Custom Global Names

```ruby
# Override automatic global name detection
IslandJS Rails.configure do |config|
  config.global_name_overrides = {
    '@mui/material' => 'MaterialUI',
    'react-router-dom' => 'ReactRouterDOM'
  }
end
```

### Composable Architecture

```javascript
// Create your own namespace
window.islandjsRailsApp = {
  React: window.React,
  UI: window.MaterialUI,
  Utils: window._,
  Charts: window.Chart
};

// Use in components
const { React, UI, Utils } = window.islandjsRailsApp;
```

### Webpack Integration

IslandJS Rails automatically updates your webpack externals:

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
# Initialize IslandJS Rails in project
IslandJS Rails.init!

# Install a package and create partial
IslandJS Rails.install!('react', '18.3.1')

# Update an existing package
IslandJS Rails.update!('react', '18.3.1')

# Remove a package (from package.json + delete partial)
IslandJS Rails.remove!('react')

# Sync all packages
IslandJS Rails.sync!

# Show status
IslandJS Rails.status!

# Clean all partials and reset webpack externals
IslandJS Rails.clean!

# Check what packages are installed
IslandJS Rails.package_installed?('react')

# Get version for a package
IslandJS Rails.version_for('react')
```

### Configuration Options

```ruby
IslandJS Rails.configure do |config|
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
rails islandjs:install[react]
rails islandjs:install[react-dom]  
rails islandjs:install[chart.js]
```

```erb
<!-- app/views/dashboard/show.html.erb -->
<%= islands %>

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

**⭐ Recommended: Use Built-in Turbo Cache**

IslandJS Rails now includes automatic Turbo cache compatibility! See the [Turbo Cache Integration](#turbo-cache-integration) section above for the modern approach with zero manual setup.

**Alternative: Manual Turbo Integration**

For custom scenarios, you can manually handle Turbo events:

```javascript
// Manual approach (not needed with react_component helper)
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
IslandJS Rails.configure do |config|
  config.global_name_overrides = {
    'conflicting-package' => 'UniqueGlobalName'
  }
end
```

**Webpack externals not updating:**
```bash
# Sync to update externals
rails islandjs:sync

# Or clean and reinstall
rails islandjs:clean
rails islandjs:install[react]
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
bundle exec rspec spec/lib/islandjs_rails/core_spec.rb

# Run with coverage report
bundle exec rspec --format documentation
```

## License

MIT License - see LICENSE file for details.

## Structure

```
lib/islandjs_rails/
├── spec/
│   ├── spec_helper.rb                    # Test setup and mocking
│   ├── lib/
│   │   ├── islandjs_rails_spec.rb             # Main module tests
│   │   └── islandjs_rails/
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
cd lib/islandjs_rails
bundle install
bundle exec rspec
```

### Individual test files:

```bash
bundle exec rspec spec/lib/islandjs_rails/core_spec.rb
bundle exec rspec spec/lib/islandjs_rails/rails_helpers_spec.rb
bundle exec rspec spec/lib/islandjs_rails/configuration_spec.rb
bundle exec rspec spec/lib/islandjs_rails/core_spec.rb
bundle exec rspec spec/lib/islandjs_rails/rails_helpers_spec.rb
bundle exec rspec spec/lib/islandjs_rails/configuration_spec.rb
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
- **CLI simulation**: All major IslandJS Rails operations and rake tasks

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

When adding new IslandJS Rails functionality:

1. Add tests to the appropriate test file
2. Use the provided test helpers for consistency
3. Mock external dependencies (CDN calls, file system operations)
4. Test both success and failure scenarios
5. Ensure tests are isolated and don't affect each other

## Continuous Integration

This test suite is designed to work with any CI system:

```yaml
# Example GitHub Actions
- name: Run IslandJS Rails tests
  run: |
    cd lib/islandjs_rails
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
- **Zero-Config Generation**: `IslandJS Rails.install_package!('@tanstack/query', generate: true)` just works
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
IslandJS Rails.install_package!('@tanstack/query', generate: true)
IslandJS Rails.install_package!('zustand', generate: true)
IslandJS Rails.install_package!('@emotion/react', generate: true)
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

**Ready to revolutionize Rails 8 frontend development?** IslandJS Rails makes modern JavaScript simple again.
