/*
  # Veridia Hiring Platform Database Schema

  ## Overview
  This migration creates the complete database structure for the Veridia hiring platform,
  including user profiles, job applications, and admin management.

  ## 1. New Tables
  
  ### `profiles`
  Extends auth.users with additional user information
  - `id` (uuid, primary key, references auth.users)
  - `email` (text, unique, not null)
  - `full_name` (text, not null)
  - `phone` (text)
  - `role` (text, default 'candidate') - either 'candidate' or 'admin'
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ### `applications`
  Stores job application submissions from candidates
  - `id` (uuid, primary key)
  - `user_id` (uuid, references profiles)
  - `full_name` (text, not null)
  - `email` (text, not null)
  - `phone` (text, not null)
  - `position_applied` (text, not null)
  - `experience_years` (integer, not null)
  - `resume_url` (text) - URL to uploaded resume
  - `cover_letter` (text)
  - `linkedin_url` (text)
  - `portfolio_url` (text)
  - `education` (text, not null)
  - `skills` (text[], array of skills)
  - `status` (text, default 'pending') - pending, reviewing, shortlisted, rejected, accepted
  - `admin_notes` (text) - internal notes for HR team
  - `created_at` (timestamptz)
  - `updated_at` (timestamptz)

  ## 2. Security
  
  ### RLS Policies
  
  #### profiles table:
  - Enable RLS
  - Authenticated users can read their own profile
  - Authenticated users can update their own profile
  - Authenticated users can insert their own profile
  - Admin users can read all profiles
  
  #### applications table:
  - Enable RLS
  - Candidates can read their own applications
  - Candidates can insert their own applications
  - Candidates can update their own applications (only if status is 'pending')
  - Admin users can read all applications
  - Admin users can update all applications

  ## 3. Important Notes
  - All tables use RLS for security
  - Default role for new users is 'candidate'
  - Application status workflow: pending → reviewing → shortlisted/rejected/accepted
  - Skills are stored as text array for flexible querying
  - Timestamps track creation and modification times
*/

-- Create profiles table
CREATE TABLE IF NOT EXISTS profiles (
  id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text UNIQUE NOT NULL,
  full_name text NOT NULL,
  phone text,
  role text NOT NULL DEFAULT 'candidate' CHECK (role IN ('candidate', 'admin')),
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Create applications table
CREATE TABLE IF NOT EXISTS applications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES profiles(id) ON DELETE CASCADE NOT NULL,
  full_name text NOT NULL,
  email text NOT NULL,
  phone text NOT NULL,
  position_applied text NOT NULL,
  experience_years integer NOT NULL,
  resume_url text,
  cover_letter text,
  linkedin_url text,
  portfolio_url text,
  education text NOT NULL,
  skills text[] DEFAULT '{}',
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'shortlisted', 'rejected', 'accepted')),
  admin_notes text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

-- Enable RLS
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE applications ENABLE ROW LEVEL SECURITY;

-- Profiles policies
CREATE POLICY "Users can read own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id OR EXISTS (
    SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin'
  ));

CREATE POLICY "Users can insert own profile"
  ON profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-- Applications policies
CREATE POLICY "Candidates can read own applications"
  ON applications FOR SELECT
  TO authenticated
  USING (
    user_id = auth.uid() OR 
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

CREATE POLICY "Candidates can insert own applications"
  ON applications FOR INSERT
  TO authenticated
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Candidates can update own pending applications"
  ON applications FOR UPDATE
  TO authenticated
  USING (
    (user_id = auth.uid() AND status = 'pending') OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    (user_id = auth.uid() AND status = 'pending') OR
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_applications_user_id ON applications(user_id);
CREATE INDEX IF NOT EXISTS idx_applications_status ON applications(status);
CREATE INDEX IF NOT EXISTS idx_applications_created_at ON applications(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Triggers for updated_at
DROP TRIGGER IF EXISTS update_profiles_updated_at ON profiles;
CREATE TRIGGER update_profiles_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_applications_updated_at ON applications;
CREATE TRIGGER update_applications_updated_at
  BEFORE UPDATE ON applications
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();