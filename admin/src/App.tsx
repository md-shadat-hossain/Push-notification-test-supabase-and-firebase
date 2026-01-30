import { useState, useEffect } from 'react';
import { createClient } from '@supabase/supabase-js';

// TODO: Replace with your Supabase credentials
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL || 'YOUR_SUPABASE_URL';
const supabaseServiceKey = import.meta.env.VITE_SUPABASE_SERVICE_KEY || 'YOUR_SUPABASE_SERVICE_KEY';

const supabase = createClient(supabaseUrl, supabaseServiceKey);

interface FcmToken {
  id: string;
  token: string;
  platform: string;
  created_at: string;
}

interface SendResult {
  successCount: number;
  failureCount: number;
  failedTokens: { token: string; error: string }[];
}

function App() {
  const [tokens, setTokens] = useState<FcmToken[]>([]);
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [loading, setLoading] = useState(false);
  const [result, setResult] = useState<SendResult | null>(null);
  const [error, setError] = useState('');

  useEffect(() => {
    fetchTokens();
  }, []);

  const fetchTokens = async () => {
    const { data, error } = await supabase
      .from('fcm_tokens')
      .select('*')
      .order('created_at', { ascending: false });

    if (error) {
      setError(`Failed to fetch tokens: ${error.message}`);
    } else {
      setTokens(data || []);
    }
  };

  const sendNotification = async () => {
    if (!title || !body) {
      setError('Please enter both title and body');
      return;
    }

    if (tokens.length === 0) {
      setError('No devices registered');
      return;
    }

    setLoading(true);
    setError('');
    setResult(null);

    try {
      const response = await fetch('/api/send-notification', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          tokens: tokens.map((t) => t.token),
          title,
          body,
        }),
      });

      const data = await response.json();

      if (!response.ok) {
        throw new Error(data.error || 'Failed to send notification');
      }

      setResult(data);

      // Remove failed tokens from Supabase
      if (data.failedTokens && data.failedTokens.length > 0) {
        const failedTokenStrings = data.failedTokens.map(
          (ft: { token: string }) => ft.token
        );
        await supabase
          .from('fcm_tokens')
          .delete()
          .in('token', failedTokenStrings);
        fetchTokens(); // Refresh token list
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'An error occurred');
    } finally {
      setLoading(false);
    }
  };

  const deleteToken = async (tokenId: string) => {
    await supabase.from('fcm_tokens').delete().eq('id', tokenId);
    fetchTokens();
  };

  return (
    <div style={styles.container}>
      <h1 style={styles.title}>Push Notification Admin</h1>

      {/* Send Notification Form */}
      <div style={styles.card}>
        <h2 style={styles.cardTitle}>Send Notification</h2>

        <div style={styles.formGroup}>
          <label style={styles.label}>Title</label>
          <input
            type="text"
            value={title}
            onChange={(e) => setTitle(e.target.value)}
            style={styles.input}
            placeholder="Notification title"
          />
        </div>

        <div style={styles.formGroup}>
          <label style={styles.label}>Body</label>
          <textarea
            value={body}
            onChange={(e) => setBody(e.target.value)}
            style={styles.textarea}
            placeholder="Notification message"
            rows={3}
          />
        </div>

        <button
          onClick={sendNotification}
          disabled={loading || tokens.length === 0}
          style={{
            ...styles.button,
            opacity: loading || tokens.length === 0 ? 0.5 : 1,
          }}
        >
          {loading ? 'Sending...' : `Send to ${tokens.length} device(s)`}
        </button>

        {error && <div style={styles.error}>{error}</div>}

        {result && (
          <div style={styles.result}>
            <p>Sent: {result.successCount}</p>
            <p>Failed: {result.failureCount}</p>
          </div>
        )}
      </div>

      {/* Registered Devices */}
      <div style={styles.card}>
        <h2 style={styles.cardTitle}>
          Registered Devices ({tokens.length})
        </h2>

        <button onClick={fetchTokens} style={styles.refreshButton}>
          Refresh
        </button>

        {tokens.length === 0 ? (
          <p style={styles.noDevices}>No devices registered yet</p>
        ) : (
          <div style={styles.tokenList}>
            {tokens.map((token) => (
              <div key={token.id} style={styles.tokenItem}>
                <div style={styles.tokenInfo}>
                  <span style={styles.platform}>{token.platform}</span>
                  <span style={styles.tokenText}>
                    {token.token.substring(0, 30)}...
                  </span>
                  <span style={styles.date}>
                    {new Date(token.created_at).toLocaleDateString()}
                  </span>
                </div>
                <button
                  onClick={() => deleteToken(token.id)}
                  style={styles.deleteButton}
                >
                  Delete
                </button>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

const styles: Record<string, React.CSSProperties> = {
  container: {
    maxWidth: 600,
    margin: '0 auto',
    padding: 20,
    fontFamily: 'system-ui, sans-serif',
  },
  title: {
    textAlign: 'center',
    color: '#333',
  },
  card: {
    background: '#fff',
    borderRadius: 8,
    padding: 20,
    marginBottom: 20,
    boxShadow: '0 2px 8px rgba(0,0,0,0.1)',
  },
  cardTitle: {
    margin: '0 0 16px 0',
    fontSize: 18,
    color: '#333',
  },
  formGroup: {
    marginBottom: 16,
  },
  label: {
    display: 'block',
    marginBottom: 4,
    fontWeight: 500,
    color: '#555',
  },
  input: {
    width: '100%',
    padding: '10px 12px',
    border: '1px solid #ddd',
    borderRadius: 4,
    fontSize: 14,
    boxSizing: 'border-box',
  },
  textarea: {
    width: '100%',
    padding: '10px 12px',
    border: '1px solid #ddd',
    borderRadius: 4,
    fontSize: 14,
    resize: 'vertical',
    boxSizing: 'border-box',
  },
  button: {
    width: '100%',
    padding: '12px 16px',
    background: '#6366f1',
    color: '#fff',
    border: 'none',
    borderRadius: 4,
    fontSize: 16,
    fontWeight: 500,
    cursor: 'pointer',
  },
  refreshButton: {
    padding: '8px 16px',
    background: '#f3f4f6',
    color: '#333',
    border: '1px solid #ddd',
    borderRadius: 4,
    fontSize: 14,
    cursor: 'pointer',
    marginBottom: 16,
  },
  error: {
    marginTop: 12,
    padding: 12,
    background: '#fef2f2',
    color: '#dc2626',
    borderRadius: 4,
  },
  result: {
    marginTop: 12,
    padding: 12,
    background: '#f0fdf4',
    color: '#16a34a',
    borderRadius: 4,
  },
  noDevices: {
    color: '#666',
    fontStyle: 'italic',
  },
  tokenList: {
    display: 'flex',
    flexDirection: 'column',
    gap: 8,
  },
  tokenItem: {
    display: 'flex',
    justifyContent: 'space-between',
    alignItems: 'center',
    padding: 12,
    background: '#f9fafb',
    borderRadius: 4,
  },
  tokenInfo: {
    display: 'flex',
    flexDirection: 'column',
    gap: 4,
  },
  platform: {
    textTransform: 'uppercase',
    fontSize: 12,
    fontWeight: 600,
    color: '#6366f1',
  },
  tokenText: {
    fontSize: 12,
    color: '#666',
    fontFamily: 'monospace',
  },
  date: {
    fontSize: 12,
    color: '#999',
  },
  deleteButton: {
    padding: '6px 12px',
    background: '#fee2e2',
    color: '#dc2626',
    border: 'none',
    borderRadius: 4,
    fontSize: 12,
    cursor: 'pointer',
  },
};

export default App;
