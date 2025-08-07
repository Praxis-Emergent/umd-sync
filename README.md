# IslandJS Rails — Turbo compatible JSX in seconds

Launch quickly, upgrade to vite only when needed.

[![CI](https://github.com/praxis-emergent/islandjs-rails/actions/workflows/github-actions-demo.yml/badge.svg)](https://github.com/praxis-emergent/islandjs-rails/actions/workflows/github-actions-demo.yml)
[![Test Coverage](https://img.shields.io/badge/coverage-89.09%25-brightgreen.svg)](coverage/index.html)
[![RSpec Tests](https://img.shields.io/badge/tests-162%20passing-brightgreen.svg)](spec/)
[![Rails 8 Ready](https://img.shields.io/badge/Rails%208-Ready-brightgreen.svg)](#rails-8-ready)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%203.0-red.svg)](https://www.ruby-lang.org/)

IslandJS Rails supports the development of React (or other JS library) islands in Rails apps by synchronizing `package.json` defined dependencies with UMD libraries served in `public/islands/vendor`.

Write Turbo compatible JSX in `app/javascript/islands/components/` and render it with a `react_component` helper in ERB templates (including Turbo Stream partials) — Vue and other framework support can be added with a bit of work.

## Quick Start

IslandJS Rails requires:
- **Node.js** 16+ with **npm** and **yarn** (development only)
- **Rails** 7+ (tested with Rails 8)

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

### Run Yarn In Development
```bash
yarn watch
```

### Render React Components
```erb
<!-- In any view -->
<%= react_component('DashboardApp', { userId: current_user.id }) %>

<!-- With placeholder (v0.2.0+) to prevent layout shift -->
<%= react_component('DashboardApp', { userId: current_user.id }) do %>
  <div class="loading-skeleton">Loading dashboard...</div>
<% end %>
```

### Build For Production
```bash
yarn build # you may remove any stale islandjs bundles before commit
```

> 💡 **Turbo Cache Compatible**: React components automatically persist state across Turbo navigation! See [Turbo Cache Integration](#turbo-cache-integration) for details.

### Write Modern JSX (with Turbo Cache Support)

Every React component should be written to accept a single `containerId` prop and rendered using the `react_component` view helper, which accepts a JSON object of props.

The props data passed into `react_component` is automatically available via `useTurboProps` and can be optionally cached using `useTurboCache` for persistence across Turbo navigation.

```jsx
// jsx/components/DashboardApp.jsx
import React, { useState, useEffect } from 'react';
import { useTurboProps, useTurboCache } from '../utils/turbo.js';

function DashboardApp({ containerId }) {
  // Read initial state from data-initial-state attribute
  const initialProps = useTurboProps(containerId);
  
  const [userId] = useState(initialProps.userId);
  const [welcomeCount, setWelcomeCount] = useState(initialProps.welcomeCount || 0);

  // Setup turbo cache persistence for state across navigation
  useEffect(() => {
    const cleanup = useTurboCache(containerId, { userId, welcomeCount }, true);
    return cleanup;
  }, [containerId, userId, welcomeCount]);

  return (
    <div>
      <h2>Welcome user {userId}!</h2>
      <p>You've visited this dashboard {welcomeCount} times</p>
      <button onClick={() => setWelcomeCount(prev => prev + 1)}>
        Visit Again
      </button>
    </div>
  );
}

export default DashboardApp;
```

### Important
Do not pass sensitive data to the client-side via props. Pass it any other (secure) way — props are encoded in the HTML and are visible to the client and any other scripts.

## Why IslandJS Rails?

### Perfect for Rails 8
IslandJS Rails aligns perfectly with **Rails 8's philosophy** of simplicity and convention over configuration:

- **Asset Pipeline Simplification**: Rails 8 streamlined assets - IslandJS Rails fits seamlessly 
- **Hotwire + React Islands**: The sweet spot for Rails 8 frontend development
- **Fast Development & Deployment**: Instant builds, no library rebundling

### The Problem IslandJS Rails Solves
Modern Rails developers face a painful choice:
- **Bundle everything**: Massive webpack configs, slow builds, bundle bloat
- **Skip modern JS**: Miss out on React and popular npm packages

IslandJS Rails offers a middle way: a simple, zero-config solution for adding React and other JS libraries to your Rails app. Get 80% of reactive use cases covered for 5% of the hassle.

**Important Note:** IslandJS Rails works with packages that ship UMD builds. Many popular packages have UMD builds, but some modern packages do not — React 19+ removed UMD builds entirely. Future versions of IslandJS Rails will support local UMD generation for some packages (such as [React 19+](https://github.com/lofcz/umd-react)).

### The IslandJS Rails Solution
```bash
# Instead of complex vite/webpack configuration:
rails "islandjs:install[react,18.3.1]"
rails "islandjs:install[react-beautiful-dnd]"
rails "islandjs:install[quill]"
rails "islandjs:install[recharts]"
rails "islandjs:install[lodash]"
```

**Result**: Zero-to-no webpack configuration, instant prod builds, access to hundreds of UMD packages.

### Access UMD installed JS packages via the window from within React components:
```bash
\\ in SomeComponent.jsx
const quill = new window.Quill("#editor", {
  theme: "snow",
});
```

## Rails 8 Ready

✅ **Tested against Rails 8**  
✅ **Compatible with Rails 8 asset pipeline**  
✅ **Optimized for Hotwire/Turbo workflows**  
✅ **Zero-config React islands**

## Core Features

- **Convention over Configuration** - Works with sensible defaults
- **Package.json Integration** - (npm + yarn)
- **CDN Downloads** - Fetches UMD builds from unpkg.com and jsdelivr.net
- **Rails Integration** - Serves auto-generated vendor UMD files for seamless integration
- **Webpack Externals** - Updates webpack config to prevent duplicate bundling while allowing development in jsx or other formats
- **Placeholder Support** - Eliminate layout shift with automatic placeholder management ⚡ *New in v0.2.0*
- **Flexible Architecture** - Compose and namespace libraries as needed

## CLI Commands

### 📦 Package Management

#### Rails Tasks

```bash
# Initialize IslandJS Rails in your project
rails islandjs:init

# Install packages (adds to package.json + saves to vendor directory)
rails "islandjs:install[react]"
rails "islandjs:install[react,18.3.1]"       # With specific version
rails "islandjs:install[lodash]"

# Update packages (updates package.json + refreshes vendor files)
rails "islandjs:update[react]"
rails "islandjs:update[react,18.3.1]"       # To specific version

# Remove packages (removes from package.json + deletes vendor files)
rails "islandjs:remove[react]"
rails "islandjs:remove[lodash]"

# Clean all UMD files (removes ALL vendor files)
rails islandjs:clean

# Show configuration
rails islandjs:config
```

### 🗂️ Vendor System Management

IslandJS Rails includes additional tasks for managing the vendor file system:

```bash
# Rebuild the combined vendor bundle (when using :external_combined mode)
rails islandjs:vendor:rebuild

# Show vendor system status and file sizes
rails islandjs:vendor:status
```

**Vendor System Modes:**
- **`:external_split`** (default): Each library served as separate file from `public/islands/vendor/`
- **`:external_combined`**: All libraries concatenated into single bundle with cache-busting hash

**Benefits of Vendor System:**
- 🚀 **Better Performance**: Browser caching, parallel downloads, no Base64 bloat
- 📦 **Scalable**: File size doesn't affect HTML parsing or memory usage
- 🔧 **Maintainable**: Clear separation between vendor libraries and application code
- 🌐 **CDN Ready**: Vendor files can be easily moved to CDN for global distribution (serving from CDN will be configurable granularly in future versions — where possible)

### 🛠️ Development & Production Commands

For development and building your JavaScript:

```bash
# Development - watch for changes and rebuild automatically
yarn watch
# Or with npm: npm run watch

# Production - build optimized bundle for deployment
yarn build
# Or with npm: npm run build

# Install dependencies (after adding packages via islandjs:install)
yarn install
# Or with npm: npm install
```

**Development Workflow:**
1. Run `yarn watch` (or `npm run watch`) in one terminal
2. Edit your components in `app/javascript/islands/components/`
3. Changes are automatically compiled to `public/`

**Production Deployment:**
1. Run `yarn build` (or `npm run build`) to create optimized bundle
2. Commit the built assets: `git add public/islands_* && git add public/islands/*`
3. Deploy with confidence - assets are prebuilt

## 📦 Working with Scoped Packages

### What are Scoped Packages?

Scoped packages are npm packages that belong to a namespace, prefixed with `@`. Examples include:
- `@solana/web3.js`

### Installation Syntax

When installing scoped packages, you **must** include the full package name with the `@` symbol:

```bash
# ✅ Correct - Full scoped package name
rails "islandjs:install[@solana/web3.js,1.98.4]"

# ❌ Incorrect - Missing .js suffix
rails "islandjs:install[@solana/web3,1.98.4]"

# ❌ Incorrect - Missing scope
rails "islandjs:install[web3.js,1.98.4]"
```

### Shell Escaping

The `@` symbol is handled automatically by Rails task syntax when using double quotes. No additional escaping is needed:

```bash
# ✅ Works perfectly
rails "islandjs:install[@solana/web3.js]"

# ✅ Also works (with version)
rails "islandjs:install[@solana/web3.js,1.98.4]"

# ⚠️ May not work in some shells without quotes
rails islandjs:install[@solana/web3.js]  # Avoid this
```

### Global Name Detection

IslandJS Rails automatically converts scoped package names to valid JavaScript global names:

```ruby
# Automatic conversions:
'@solana/web3.js'     => 'solanaWeb3'     # Scope removed, camelCase
```

### Custom Global Names

You can override the automatic global name detection for scoped packages:

Solana Web3.js is automatically detected with the built-in global name mapping `solanaWeb3`.

### Usage in Components

Once installed, scoped packages work exactly like regular packages:

```jsx
// jsx/components/SolanaComponent.jsx
import React from 'react';

function SolanaComponent() {
  // solanaWeb3 is automatically available as a global variable on the window object
  const connection = new window.solanaWeb3.Connection('https://api.devnet.solana.com');
  
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
    "react": "React",
    "react-dom": "ReactDOM"
  },
  // ... rest of config
};
```

### Troubleshooting Scoped Packages

**Issue: Package not found**
```bash
# Check the exact package name on npm
npm view @solana/web3.js

# Ensure you're using the full name
rails "islandjs:install[@solana/web3.js]"  # ✅ Correct
rails "islandjs:install[@solana/web3]"     # ❌ Wrong
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
| `install` | Adds package via yarn + downloads UMD + saves to vendor | `rails islandjs:install[react]` |
| `update` | Updates package version + refreshes UMD | `rails islandjs:update[react,18.3.1]` |
| `remove` | Removes package via yarn + deletes vendor files | `rails islandjs:remove[react]` |
| `clean` | Removes ALL vendor files (destructive!) | `rails islandjs:clean` |

### Configuration

```ruby
# config/initializers/islandjs.rb
IslandjsRails.configure do |config|
  # Directory for ERB partials (default: app/views/shared/islands)
  config.partials_dir = Rails.root.join('app/views/shared/islands')
  
  # Webpack configuration path
  config.webpack_config_path = Rails.root.join('webpack.config.js')
  
  # Vendor file delivery mode (default: :external_split)
  config.vendor_script_mode = :external_split    # One file per library
  # config.vendor_script_mode = :external_combined # Single combined bundle
  
  # Vendor files directory (default: public/islands/vendor)
  config.vendor_dir = Rails.root.join('public/islands/vendor')
  
  # Combined bundle filename base (default: 'islands-vendor')
  config.combined_basename = 'islands-vendor'
  
  # Library loading order for combined bundles
  config.vendor_order = ['react', 'react-dom', 'lodash']
end
```

## Rails Integration

### Helpers

#### `islands`
Single helper that includes all UMD vendor scripts and your webpack bundle.

```erb
<%= islands %>
```

This automatically loads:
- All UMD libraries from vendor files (either split or combined mode)
- Your webpack bundle
- Debug information in development

#### `react_component(name, props, options, &block)`
Renders a React component with Turbo-compatible lifecycle and optional placeholder support.

```erb
<%= react_component('UserProfile', { 
  userId: current_user.id,
  theme: 'dark' 
}, {
  container_id: 'profile-widget',
  namespace: 'window.islandjsRails'
}) %>
```

**Available Options:**
- `container_id`: Custom ID for the container element
- `namespace`: JavaScript namespace for component access (default: `window.islandjsRails`)
- `tag`: HTML tag for container (default: `div`)
- `class`: CSS class for container
- `placeholder_class`: CSS class for placeholder content
- `placeholder_style`: Inline styles for placeholder content

## Placeholder Support

⚡ **New in v0.2.0** - Prevent layout shift when React components mount!

The `react_component` helper now supports placeholder content that displays while your React component loads, eliminating the "jumpy" effect common in dynamic content updates via Turbo Streams.

### Problem Solved

When React components mount (especially via Turbo Stream updates), there's often a brief moment where content height changes, causing layout shift:

```erb
<!-- Before: Content jumps when component mounts -->
<%= react_component("Reactions", { postId: post.id }) %>
<!-- Page content shifts down when reactions component renders -->
```

### Solution: Three Placeholder Patterns

#### 1. ERB Block Placeholder (Most Flexible)
```erb
<%= react_component("Reactions", { postId: post.id }) do %>
  <div class="reactions-skeleton">
    <div class="skeleton-button">👍</div>
    <div class="skeleton-button">❤️</div>
    <div class="skeleton-button">🚀</div>
    <div class="skeleton-count">Loading...</div>
  </div>
<% end %>
```

#### 2. CSS Class Placeholder (Design System Friendly)
```erb
<%= react_component("Reactions", { postId: post.id }, {
  placeholder_class: "reactions-skeleton"
}) %>
```

#### 3. Inline Style Placeholder (Quick & Simple)
```erb
<%= react_component("Reactions", { postId: post.id }, {
  placeholder_style: "height: 40px; background: #f8f9fa; border-radius: 4px;"
}) %>
```

### How It Works

1. **Placeholder renders** immediately with your ERB content or styles
2. **React mounts** and automatically replaces the entire container contents
3. **Zero manual cleanup** - React's natural DOM replacement handles removal
4. **On mount errors** - placeholder stays visible as graceful fallback

### Perfect for Turbo Streams

Placeholders shine in Turbo Stream scenarios where content updates dynamically:

```erb
<!-- app/views/posts/_reactions.html.erb -->
<%= turbo_stream.replace "post_#{@post.id}_reactions" do %>
  <%= react_component("Reactions", { 
    postId: @post.id, 
    initialCount: @post.reactions.count 
  }) do %>
    <div class="reactions-placeholder" style="height: 32px;">
      <span class="text-muted">Loading reactions...</span>
    </div>
  <% end %>
<% end %>
```

### Benefits

- ✅ **Eliminates layout shift** during component mounting
- ✅ **Turbo Stream compatible** - perfect for dynamic updates  
- ✅ **Zero JavaScript required** - handled automatically by the helper
- ✅ **Graceful degradation** - placeholder persists if React fails to load
- ✅ **Design system friendly** - use your existing skeleton/loading styles
- ✅ **Performance optimized** - leverages React's natural DOM clearing

## Turbo Cache Integration

IslandJS Rails includes **built-in Turbo cache compatibility** for React components, ensuring state persists seamlessly across navigation.

### How It Works

The `react_component` helper automatically:
1. **Stores initial props** as JSON in `data-initial-state` attributes
2. **Generates unique container IDs** for each component instance  
3. **Passes only the container ID** to the React component

This allows React components to persist state changes back to the data attribute before turbo caches the page.

### Example: Turbo-Compatible Component

See the complete working example: [`HelloWorld.jsx`](app/javascript/islands/components/HelloWorld.jsx)

```jsx
import React, { useState, useEffect } from 'react';
import { useTurboProps, useTurboCache } from '../utils/turbo.js';

const HelloWorld = ({ containerId }) => {
  // Read initial state from data-initial-state attribute
  const initialProps = useTurboProps(containerId);
  
  const [count, setCount] = useState(initialProps.count || 0);
  const [message, setMessage] = useState(initialProps.message || "Hello!");

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

### Turbo Utility Functions

IslandJS Rails provides utility functions for Turbo compatibility:

```javascript
// Get initial state from container's data attribute
const initialProps = useTurboProps(containerId);

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

### Built-in Global Names

IslandJS Rails includes built-in global name mappings for popular libraries:

- `react` → `React`
- `react-dom` → `ReactDOM`
- `lodash` → `_`
- `@solana/web3.js` → `solanaWeb3`
- And more common libraries

For other packages, kebab-case names are automatically converted to camelCase.

### Composable Architecture

```javascript
// Create your own namespace (or use the default window.islandjsRails)
window.islandjsRails = {
  React: window.React,
  UI: window.MaterialUI,
  Utils: window._,
  Charts: window.Chart
};

// Use in components
const { React, UI, Utils } = window.islandjsRails;
```

### Webpack Integration

IslandJS Rails automatically updates your webpack externals:

```javascript
// webpack.config.js (auto-generated)
module.exports = {
  externals: {
    'react': 'React',
    'lodash': '_'
  }
};
```

### Configuration Options

```ruby
IslandjsRails.configure do |config|
  # Directory for ERB partials (default: app/views/shared/islands)
  config.partials_dir = Rails.root.join('app/views/shared/islands')
  
  # Path to webpack config (default: webpack.config.js)
  config.webpack_config_path = Rails.root.join('webpack.config.js')
  
  # Path to package.json (default: package.json)
  config.package_json_path = Rails.root.join('package.json')
  
  # Vendor file delivery mode (default: :external_split)
  config.vendor_script_mode = :external_split    # One file per library
  # config.vendor_script_mode = :external_combined # Single combined bundle
  
  # Vendor files directory (default: public/islands/vendor)
  config.vendor_dir = Rails.root.join('public/islands/vendor')
  
  # Combined bundle filename base (default: 'islands-vendor')
  config.combined_basename = 'islands-vendor'
  
  # Library loading order for combined bundles
  config.vendor_order = ['react', 'react-dom', 'lodash']
  
  # Built-in global name mappings are automatically applied
  # No custom configuration needed for common libraries
end
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
IslandJS Rails includes built-in mappings for common libraries. For packages with unusual global names, check the library's documentation or browser console to find the correct global variable name.

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
3. Run the tests (`bundle exec rspec`)
4. Commit your changes (`git commit -am 'Add amazing feature'`)
5. Push to the branch (`git push origin feature/amazing-feature`)
6. Open a Pull Request

## License

MIT License - see LICENSE file for details.

## Running Tests

### From the gem directory:

```bash
cd lib/islandjs_rails
bundle install
bundle exec rspec
```

### Coverage Reports:

```bash
# View coverage in terminal
bundle exec rspec

# Open coverage report in browser
open coverage/index.html
```

## Future Enhancements

Planned features for future releases:

- **Server-Side Rendering (SSR)**: Pre-render React components on the server
- **Component Caching**: Intelligent caching of rendered components
- **Hot Reloading**: Development mode hot reloading for React components
- **TypeScript Support**: First-class TypeScript support for UMD packages
- **Local UMD Generation**: Generate UMD builds for packages that don't ship them
- **Multi-framework Support**: Vue, Svelte, and other frameworks

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
