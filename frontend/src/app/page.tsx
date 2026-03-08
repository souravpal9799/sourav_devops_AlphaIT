'use client';

import React, { useEffect, useState } from 'react';

export default function Home() {
  const [data, setData] = useState<{ message: string; version: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Default to /api for production Ingress routing
    const base = process.env.NEXT_PUBLIC_API_URL || '/api';
    
    const fetchData = async () => {
      try {
        const res = await fetch(`${base}/message`);
        if (!res.ok) {
          throw new Error(`Failed to fetch: ${res.status} ${res.statusText}`);
        }
        const jsonData = await res.json();
        setData(jsonData);
      } catch (err: any) {
        console.error('Fetch error:', err);
        setError(err.message || 'An unexpected error occurred');
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  return (
    <main className="container">
      <div className="content-wrapper">
        {/* Header Section */}
        <header className="header">
          <h1 className="title">
            AlphaIT DevOps Demo
          </h1>
          <p className="subtitle">
            Modern Full-Stack Architecture on AWS & Kubernetes
          </p>
        </header>

        {/* Dashboard grid */}
        <div className="card-container">
          {/* Glow effect */}
          <div className="glow"></div>
          
          {/* Main Card */}
          <div className="card">
            <div className="card-header">
              <h2 className="status-title">
                <span className="status-dot"></span>
                System Status
              </h2>
              <div className="version-badge">
                v1.2.0
              </div>
            </div>

            <div className="card-body">
              {loading ? (
                <div className="loading-container">
                  <div className="spinner"></div>
                  <p style={{ marginTop: '1rem', color: 'var(--text-secondary)' }}>Connecting to Backend...</p>
                </div>
              ) : error ? (
                <div className="error-container">
                  <p className="error-title">Connection Failed</p>
                  <p className="error-msg">{error}</p>
                  <button 
                    onClick={() => window.location.reload()}
                    className="retry-btn"
                  >
                    Retry Connection
                  </button>
                </div>
              ) : (
                <div className="data-section">
                  <div className="message-box">
                    <label className="label">
                      Response from database
                    </label>
                    <p className="message-text">
                      {data?.message || 'No message received'}
                    </p>
                  </div>

                  <div className="grid">
                    <div className="stat-card">
                      <label className="label">
                        Backend Version
                      </label>
                      <p className="stat-value">{data?.version || 'Unknown'}</p>
                    </div>
                    <div className="stat-card">
                      <label className="label">
                        API Framework
                      </label>
                      <p className="stat-value">FastAPI + SQLAlchemy</p>
                    </div>
                  </div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Footer */}
        <footer>
          <p>&copy; 2024 AlphaIT DevOps Project. All segments operational.</p>
        </footer>
      </div>
    </main>
  );
}
