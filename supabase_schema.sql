-- ====================================================================
-- FINTECH DIGITAL WALLET SUPABASE DATABASE SCHEMA & RLS POLICIES
-- Run this script in the Supabase SQL Editor (https://supabase.com/dashboard)
-- ====================================================================

-- 1. Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 2. PROFILES TABLE
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  username TEXT UNIQUE NOT NULL,
  email TEXT UNIQUE NOT NULL,
  phone TEXT,
  country TEXT DEFAULT 'India',
  state TEXT,
  city TEXT,
  date_of_birth DATE,
  gender TEXT,
  occupation TEXT,
  avatar_url TEXT,
  is_verified BOOLEAN DEFAULT FALSE,
  account_status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 3. WALLETS TABLE
CREATE TABLE IF NOT EXISTS public.wallets (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  wallet_number TEXT UNIQUE NOT NULL,
  balance NUMERIC(14,2) DEFAULT 0.00,
  currency TEXT DEFAULT 'INR',
  daily_limit NUMERIC(14,2) DEFAULT 50000.00,
  monthly_limit NUMERIC(14,2) DEFAULT 500000.00,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. WALLET TRANSACTIONS TABLE
CREATE TABLE IF NOT EXISTS public.wallet_transactions (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  wallet_id UUID REFERENCES public.wallets(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  transaction_type TEXT NOT NULL, -- 'topup', 'withdraw', 'transfer', 'expense', 'qr_pay'
  amount NUMERIC(14,2) NOT NULL,
  payment_method TEXT,
  status TEXT DEFAULT 'completed',
  category TEXT DEFAULT 'General & Other',
  description TEXT,
  reference_number TEXT UNIQUE NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 5. USER SETTINGS TABLE
CREATE TABLE IF NOT EXISTS public.user_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  theme TEXT DEFAULT 'dark',
  language TEXT DEFAULT 'en',
  currency TEXT DEFAULT 'INR',
  privacy_profile_visibility TEXT DEFAULT 'contacts',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 6. NOTIFICATION SETTINGS TABLE
CREATE TABLE IF NOT EXISTS public.notification_settings (
  user_id UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  email_notifications BOOLEAN DEFAULT TRUE,
  push_notifications BOOLEAN DEFAULT TRUE,
  sms_notifications BOOLEAN DEFAULT TRUE,
  transfer_alerts BOOLEAN DEFAULT TRUE,
  expense_alerts BOOLEAN DEFAULT TRUE,
  budget_alerts BOOLEAN DEFAULT TRUE,
  security_alerts BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 7. QR CODES TABLE
CREATE TABLE IF NOT EXISTS public.qr_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID UNIQUE REFERENCES public.profiles(id) ON DELETE CASCADE,
  qr_token TEXT UNIQUE NOT NULL,
  qr_code_id TEXT UNIQUE NOT NULL,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 8. ACTIVITY LOGS TABLE
CREATE TABLE IF NOT EXISTS public.activity_logs (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
  module TEXT DEFAULT 'security',
  action TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  reference_id TEXT,
  metadata JSONB DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ====================================================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ====================================================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.qr_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_logs ENABLE ROW LEVEL SECURITY;

-- PROFILES RLS
CREATE POLICY "Users can view own profile or public profile data"
  ON public.profiles FOR SELECT
  USING (true);

CREATE POLICY "Users can insert own profile on signup"
  ON public.profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- WALLETS RLS
CREATE POLICY "Users can view own wallet"
  ON public.wallets FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own wallet on signup"
  ON public.wallets FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own wallet balance"
  ON public.wallets FOR UPDATE
  USING (auth.uid() = user_id);

-- WALLET TRANSACTIONS RLS
CREATE POLICY "Users can view own transactions"
  ON public.wallet_transactions FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert transactions for own wallet"
  ON public.wallet_transactions FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- USER SETTINGS RLS
CREATE POLICY "Users can view own settings"
  ON public.user_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update own settings"
  ON public.user_settings FOR ALL
  USING (auth.uid() = user_id);

-- NOTIFICATION SETTINGS RLS
CREATE POLICY "Users can view own notification settings"
  ON public.notification_settings FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert/update own notification settings"
  ON public.notification_settings FOR ALL
  USING (auth.uid() = user_id);

-- QR CODES RLS
CREATE POLICY "Users can view own QR codes or scan active QR"
  ON public.qr_codes FOR SELECT
  USING (true);

CREATE POLICY "Users can create/update own QR code"
  ON public.qr_codes FOR ALL
  USING (auth.uid() = user_id);

-- ACTIVITY LOGS RLS
CREATE POLICY "Users can view own activity logs"
  ON public.activity_logs FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own activity logs"
  ON public.activity_logs FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- ====================================================================
-- AUTOMATIC PROFILE TRIGGER ON AUTH.USERS SIGNUP (RECOMMENDED)
-- ====================================================================
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.profiles (id, first_name, last_name, username, email, phone, country, state, city, date_of_birth, gender, occupation, avatar_url)
  VALUES (
    new.id,
    COALESCE(new.raw_user_meta_data->>'first_name', 'User'),
    COALESCE(new.raw_user_meta_data->>'last_name', ''),
    COALESCE(new.raw_user_meta_data->>'username', CONCAT('user_', SUBSTRING(new.id::text FROM 1 FOR 8))),
    new.email,
    COALESCE(new.raw_user_meta_data->>'phone', ''),
    COALESCE(new.raw_user_meta_data->>'country', 'India'),
    COALESCE(new.raw_user_meta_data->>'state', ''),
    COALESCE(new.raw_user_meta_data->>'city', ''),
    COALESCE((new.raw_user_meta_data->>'date_of_birth')::date, CURRENT_DATE - INTERVAL '20 years'),
    COALESCE(new.raw_user_meta_data->>'gender', 'Other'),
    COALESCE(new.raw_user_meta_data->>'occupation', ''),
    COALESCE(new.raw_user_meta_data->>'avatar_url', '')
  )
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.wallets (user_id, wallet_number, balance, currency)
  VALUES (
    new.id,
    CONCAT('WAL-', FLOOR(1000000000 + RANDOM() * 9000000000)::text),
    0.00,
    'INR'
  )
  ON CONFLICT (user_id) DO NOTHING;

  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to run after a user signs up via Supabase Auth
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
