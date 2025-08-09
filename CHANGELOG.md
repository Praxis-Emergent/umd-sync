# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.0] - 2025-08-09

### Added
- **Vendor Script Helper**: New `extra_vendor_tag` helper method for including third-party JavaScript libraries from the vendor directory
- **Enhanced Package Template**: Updated `lib/templates/package.json` with improved webpack configuration and dependencies

### Enhanced
- Simplified vendor asset integration with automatic Turbo tracking
- Better support for third-party library inclusion in Rails applications

## [0.2.1] - 2025-08-06

### Fixed
- Push correct branch — feature branch was released on 0.2.0

## [0.2.0] - 2025-01-04

### Added
- **Placeholder Support**: New placeholder functionality for `react_component` helper to prevent layout shift during component mounting
- **Three Placeholder Patterns**: ERB block, CSS class, and inline style options for maximum flexibility
- **Turbo Stream Optimization**: Perfect integration with Turbo Stream updates to eliminate "jumpy" content behavior
- **Automatic Cleanup**: Leverages React's natural DOM replacement for reliable placeholder removal
- **Error Handling**: Graceful fallback that keeps placeholder visible if React fails to mount

### Enhanced
- `react_component` helper now accepts optional block for custom placeholder content
- Added `placeholder_class` and `placeholder_style` options for quick placeholder styling
- Improved error resilience in React mounting process

### Documentation
- Comprehensive placeholder documentation with real-world examples
- Turbo Stream integration patterns and best practices
- Updated helper method signatures and available options

## [0.1.0] - 2025-08-04

### Added
- Initial release of IslandJS Rails
- JavaScript islands for Rails with little webpack complexity
- UMD library loading from CDNs
- ERB partial integration
- Turbo-compatible lifecycle management
- Support for React added — other frameworks possible
