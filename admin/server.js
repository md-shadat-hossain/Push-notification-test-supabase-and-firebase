import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import admin from 'firebase-admin';
import { createClient } from '@supabase/supabase-js';

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Supabase
const supabase = createClient(
  process.env.VITE_SUPABASE_URL,
  process.env.VITE_SUPABASE_SERVICE_KEY
);

// Initialize Firebase Admin SDK
const serviceAccount = {
  projectId: process.env.FIREBASE_PROJECT_ID,
  privateKey: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
  clientEmail: process.env.FIREBASE_CLIENT_EMAIL,
};

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

// Send notification to multiple tokens
app.post('/api/send-notification', async (req, res) => {
  try {
    const { tokens, title, body } = req.body;

    if (!tokens || tokens.length === 0) {
      return res.status(400).json({ error: 'No tokens provided' });
    }

    if (!title || !body) {
      return res.status(400).json({ error: 'Title and body are required' });
    }

    const message = {
      notification: {
        title,
        body,
      },
      tokens,
    };

    const response = await admin.messaging().sendEachForMulticast(message);

    // Save notification to Supabase
    const { data: notification, error: notifError } = await supabase
      .from('notifications')
      .insert({ title, body })
      .select('id')
      .single();

    if (notifError) {
      console.error('Error saving notification:', notifError);
    } else {
      // Save recipients
      const recipients = tokens.map((token, idx) => ({
        notification_id: notification.id,
        fcm_token: token,
        status: response.responses[idx]?.success ? 'sent' : 'failed',
      }));

      await supabase.from('notification_recipients').insert(recipients);
    }

    // Collect failed tokens
    const failedTokens = [];
    response.responses.forEach((resp, idx) => {
      if (!resp.success) {
        failedTokens.push({
          token: tokens[idx],
          error: resp.error?.message,
        });
      }
    });

    res.json({
      successCount: response.successCount,
      failureCount: response.failureCount,
      failedTokens,
    });
  } catch (error) {
    console.error('Error sending notification:', error);
    res.status(500).json({ error: error.message });
  }
});

// Get notifications for a specific FCM token
app.get('/api/notifications/:token', async (req, res) => {
  try {
    const { token } = req.params;

    const { data, error } = await supabase
      .from('notification_recipients')
      .select(`
        id,
        status,
        created_at,
        notifications (
          id,
          title,
          body,
          sent_at
        )
      `)
      .eq('fcm_token', token)
      .order('created_at', { ascending: false });

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    // Flatten the response
    const notifications = data.map((item) => ({
      id: item.notifications.id,
      title: item.notifications.title,
      body: item.notifications.body,
      sent_at: item.notifications.sent_at,
      status: item.status,
    }));

    res.json(notifications);
  } catch (error) {
    console.error('Error fetching notifications:', error);
    res.status(500).json({ error: error.message });
  }
});

const PORT = process.env.PORT || 3001;
app.listen(PORT, () => {
  console.log(`Server running on http://localhost:${PORT}`);
});
