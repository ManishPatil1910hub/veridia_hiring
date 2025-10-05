/*
  # Enable pg_net Extension

  1. Changes
    - Enables pg_net extension for HTTP requests from database functions
    - Required for email notification triggers to work
*/

CREATE EXTENSION IF NOT EXISTS pg_net;