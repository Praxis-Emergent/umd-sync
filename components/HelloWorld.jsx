import React from 'react';

const HelloWorld = ({ name = 'World' }) => {
  return (
    <div style={{
      padding: '20px',
      border: '2px solid #4CAF50',
      borderRadius: '8px',
      backgroundColor: '#f9f9f9',
      textAlign: 'center',
      margin: '20px 0'
    }}>
      <h2 style={{ color: '#4CAF50', margin: '0 0 10px 0' }}>
        🏝️ IslandJS Rails
      </h2>
      <p style={{ margin: '0', fontSize: '18px' }}>
        Hello, {name}! Your React island is working perfectly.
      </p>
      <p style={{ margin: '10px 0 0 0', fontSize: '14px', color: '#666' }}>
        Edit this component in <code>components/HelloWorld.jsx</code>
      </p>
    </div>
  );
};

export default HelloWorld;
