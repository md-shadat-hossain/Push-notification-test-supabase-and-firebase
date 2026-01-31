 -- Step 1 - Run this first:
 CREATE TABLE notifications (                                                                                                                                                                      CREATE TABLE notifications (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,                                                                                                                                                   
    title TEXT NOT NULL,                                                                                                                                                                             
    body TEXT NOT NULL,
    sent_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  );

  -- Step 2 - Then run this:
  CREATE TABLE notification_recipients (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    notification_id UUID REFERENCES notifications(id) ON DELETE CASCADE,
    fcm_token TEXT NOT NULL,
    status TEXT DEFAULT 'sent',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
  );

  -- Step 3 - Then run this:
  ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
  ALTER TABLE notification_recipients ENABLE ROW LEVEL SECURITY;

  CREATE POLICY "Allow all" ON notifications FOR ALL USING (true) WITH CHECK (true);
  CREATE POLICY "Allow all" ON notification_recipients FOR ALL USING (true) WITH CHECK (true);

  CREATE INDEX idx_notification_recipients_token ON notification_recipients(fcm_token);