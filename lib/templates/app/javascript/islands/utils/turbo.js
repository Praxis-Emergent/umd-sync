// Turbo-compatible state management utilities for React components

/**
 * Get initial state from a container's data-initial-state attribute
 * @param {string} containerId - The ID of the container element
 * @returns {Object} - Parsed initial state object
 */
export function useTurboProps(containerId) {
  const container = document.getElementById(containerId);
  if (!container) {
    console.warn(`IslandJS Turbo: Container ${containerId} not found`);
    return {};
  }

  const initialStateJson = container.dataset.initialState;
  if (!initialStateJson) {
    return {};
  }

  try {
    return JSON.parse(initialStateJson);
  } catch (e) {
    console.warn('IslandJS Turbo: Failed to parse initial state', e);
    return {};
  }
}

/**
 * Set up Turbo cache persistence for React component state
 * @param {string} containerId - The ID of the container element
 * @param {Object} currentState - Current component state to persist
 * @param {boolean} autoRestore - Whether to automatically restore state on turbo:load
 * @returns {Function} - Cleanup function to remove event listeners
 */
export function useTurboCache(containerId, currentState, autoRestore = true) {
  const container = document.getElementById(containerId);
  if (!container) {
    console.warn(`IslandJS Turbo: Container ${containerId} not found for caching`);
    return () => {};
  }

  // Immediately persist the current state to the div (don't wait for turbo:before-cache)
  try {
    const stateJson = JSON.stringify(currentState);
    container.dataset.initialState = stateJson;
  } catch (e) {
    console.warn('IslandJS Turbo: Failed to immediately serialize state', e);
  }
}

/**
 * Hook for React components to automatically manage Turbo cache persistence
 * This is a React hook that should be called from within a React component
 * @param {string} containerId - The ID of the container element
 * @param {Object} state - Current component state to persist
 * @param {Array} dependencies - Dependencies array for useEffect
 */
export function useTurboCacheEffect(containerId, state, dependencies = []) {
  // This assumes React is available globally
  if (typeof React !== 'undefined' && React.useEffect) {
    React.useEffect(() => {
      return useTurboCache(containerId, state, false);
    }, [containerId, ...dependencies]);
  } else {
    console.warn('IslandJS Turbo: React.useEffect not available for useTurboCacheEffect');
  }
}

/**
 * Manually persist state to container for components that don't use the hook
 * @param {string} containerId - The ID of the container element  
 * @param {Object} state - State object to persist
 */
export function persistState(containerId, state) {
  const container = document.getElementById(containerId);
  if (!container) {
    console.warn(`IslandJS Turbo: Container ${containerId} not found for state persistence`);
    return;
  }

  try {
    const stateJson = JSON.stringify(state);
    container.dataset.initialState = stateJson;
  } catch (e) {
    console.warn('IslandJS Turbo: Failed to serialize state', e);
  }
} 