'use client';

import { useEffect, useState } from 'react';

export default function Home() {
  const [data, setData] = useState<{ message: string; version: string } | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    fetch('/api/message')
      .then((res) => {
        if (!res.ok) throw new Error('Network response was not ok');
        return res.json();
      })
      .then((data) => {
        setData(data);
        setLoading(false);
      })
      .catch((err) => {
        setError(err.message);
        setLoading(false);
      });
  }, []);

  return (
    <main style={{ maxWidth: '800px', margin: '0 auto', textAlign: 'center' }}>
      <h1>AWS DevOps demo Project</h1>
      <div style={{ padding: '2rem', border: '1px solid #eaeaea', borderRadius: '8px', marginTop: '2rem' }}>
        <h2>Backend Status</h2>
        {loading && <p>Loading data from backend...</p>}
        {error && <p style={{ color: 'red' }}>Error: {error}</p>}
        {data && (
          <div>
            <p style={{ fontSize: '1.2rem', color: '#0070f3' }}>
              <strong>Message from DB:</strong> {data.message}
            </p>
            <p style={{ marginTop: '1rem', color: '#666' }}>
              Backend Version: {data.version}
            </p>
          </div>
        )}
      </div>
    </main>
  );
}
