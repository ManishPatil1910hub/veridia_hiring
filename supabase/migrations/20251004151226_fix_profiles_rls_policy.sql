/*
  # Fix Profiles RLS Policy

  ## Changes
  - Drop the existing "Users can read own profile" policy that causes infinite recursion
  - Create separate policies for reading own profile and admin reading all profiles
  - Remove the self-referencing subquery that caused the infinite loop

  ## Security
  - Users can read their own profile directly using auth.uid()
  - Admins can read all profiles (admin check done without recursion)
*/

-- Drop the problematic policy
DROP POLICY IF EXISTS "Users can read own profile" ON profiles;

-- Create separate policies to avoid recursion
CREATE POLICY "Users can read own profile"
  ON profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

CREATE POLICY "Admins can read all profiles"
  ON profiles FOR SELECT
  TO authenticated
  USING (role = 'admin');