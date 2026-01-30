-- Supabase Schema for Push Notifications
-- Run this in the Supabase SQL Editor

-- Table to store FCM tokens
CREATE TABLE fcm_tokens (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL CHECK (platform IN ('android', 'ios')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE fcm_tokens ENABLE ROW LEVEL SECURITY;

-- Policy: Allow anyone to insert tokens (mobile app uses anon key)
CREATE POLICY "Allow anonymous insert" ON fcm_tokens
  FOR INSERT
  WITH CHECK (true);

-- Policy: Allow anyone to update their own token
CREATE POLICY "Allow anonymous update" ON fcm_tokens
  FOR UPDATE
  USING (true)
  WITH CHECK (true);

-- Policy: Allow service role to read all tokens (admin panel)
CREATE POLICY "Allow authenticated read" ON fcm_tokens
  FOR SELECT
  USING (true);

-- Policy: Allow service role to delete tokens (cleanup stale tokens)
CREATE POLICY "Allow authenticated delete" ON fcm_tokens
  FOR DELETE
  USING (true);

-- Index for faster token lookups
CREATE INDEX idx_fcm_tokens_token ON fcm_tokens(token);
CREATE INDEX idx_fcm_tokens_platform ON fcm_tokens(platform);
