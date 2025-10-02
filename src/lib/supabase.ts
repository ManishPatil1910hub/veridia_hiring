import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

if (!supabaseUrl || !supabaseAnonKey) {
  throw new Error('Missing Supabase environment variables');
}

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export type Profile = {
  id: string;
  email: string;
  full_name: string;
  phone: string | null;
  role: 'candidate' | 'admin';
  created_at: string;
  updated_at: string;
};

export type Application = {
  id: string;
  user_id: string;
  full_name: string;
  email: string;
  phone: string;
  position_applied: string;
  experience_years: number;
  resume_url: string | null;
  cover_letter: string | null;
  linkedin_url: string | null;
  portfolio_url: string | null;
  education: string;
  skills: string[];
  status: 'pending' | 'reviewing' | 'shortlisted' | 'rejected' | 'accepted';
  admin_notes: string | null;
  created_at: string;
  updated_at: string;
};
