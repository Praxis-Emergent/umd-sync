import React, { useState, useEffect } from 'react';
import { useTurboProps, useTurboCache } from '../utils/turbo.js';

const HelloWorld = ({ containerId }) => {
  // Get initial state from the div's data-initial-state attribute
  const initialProps = useTurboProps(containerId);
  
  // Component state with defaults, restored from turbo cache if available
  const [count, setCount] = useState(initialProps.count || 0);
  const [message, setMessage] = useState(initialProps.message || "Hello from IslandJS Rails!");
  const [customMessage, setCustomMessage] = useState(initialProps.customMessage || '');

  // Current state object for turbo caching
  const currentState = {
    count,
    message,
    customMessage
  };

  // Setup turbo cache persistence - this should run on mount and whenever state changes
  useEffect(() => {
    const cleanup = useTurboCache(containerId, currentState, true);
    return cleanup;
  }, [containerId, count, message, customMessage]);

  const handleMessageChange = (e) => {
    setCustomMessage(e.target.value);
  };

  const applyCustomMessage = () => {
    if (customMessage.trim()) {
      setMessage(customMessage.trim());
      setCustomMessage('');
    }
  };

  return (
    <div style={{
      padding: '20px',
      border: '2px solid #4F46E5',
      borderRadius: '8px',
      backgroundColor: '#F8FAFC',
      textAlign: 'center',
      fontFamily: 'system-ui, sans-serif'
    }}>
      <h2 style={{ color: '#4F46E5', margin: '0 0 16px 0' }}>
        🏝️ React + IslandjsRails (Turbo-Cache Compatible)
      </h2>
      <p style={{ margin: '0 0 16px 0', fontSize: '18px' }}>
        {message}
      </p>
      
      <div style={{ margin: '16px 0' }}>
        <input
          type="text"
          placeholder="Enter custom message"
          value={customMessage}
          onChange={handleMessageChange}
          style={{
            padding: '8px',
            marginRight: '8px',
            border: '1px solid #D1D5DB',
            borderRadius: '4px',
            fontSize: '14px'
          }}
        />
        <button
          onClick={applyCustomMessage}
          style={{
            padding: '8px 16px',
            backgroundColor: '#059669',
            color: 'white',
            border: 'none',
            borderRadius: '4px',
            cursor: 'pointer',
            fontSize: '14px',
            marginRight: '8px'
          }}
        >
          Apply Message
        </button>
      </div>

      <button
        onClick={() => setCount(count + 1)}
        style={{
          padding: '8px 16px',
          backgroundColor: '#4F46E5',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
          fontSize: '16px'
        }}
      >
        Clicked {count} times
      </button>

      <div style={{ 
        marginTop: '16px', 
        fontSize: '12px', 
        color: '#6B7280',
        textAlign: 'left',
        backgroundColor: '#F9FAFB',
        padding: '12px',
        borderRadius: '4px'
      }}>
        <strong>Turbo-Cache Demo:</strong>
        <br />• Navigate away and back - your count and message persist!
        <br />• Container ID: <code>{containerId}</code>
        <br />• State: <code>{JSON.stringify(currentState)}</code>
      </div>
    </div>
  );
};

export default HelloWorld;
