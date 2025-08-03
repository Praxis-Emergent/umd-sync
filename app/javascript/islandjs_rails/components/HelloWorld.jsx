import React, { useState } from 'react';

const HelloWorld = ({ message = "Hello from IslandjsRails!" }) => {
  const [count, setCount] = useState(0);
  
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
        🏝️ React + IslandjsRails
      </h2>
      <p style={{ margin: '0 0 16px 0', fontSize: '18px' }}>
        {message}
      </p>
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
    </div>
  );
};

export default HelloWorld;
