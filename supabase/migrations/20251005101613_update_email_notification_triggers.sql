/*
  # Update Email Notification Triggers

  1. Changes
    - Recreates notification functions with proper async HTTP handling
    - Uses pg_net for making HTTP requests to edge function
*/

-- Drop existing functions and triggers
DROP TRIGGER IF EXISTS on_application_submitted ON applications;
DROP TRIGGER IF EXISTS on_application_status_updated ON applications;
DROP FUNCTION IF EXISTS notify_application_submitted();
DROP FUNCTION IF EXISTS notify_status_updated();

-- Function to notify when application is submitted
CREATE OR REPLACE FUNCTION notify_application_submitted()
RETURNS TRIGGER AS $$
DECLARE
  user_email text;
  user_name text;
  request_id bigint;
BEGIN
  -- Get user details
  SELECT email, full_name INTO user_email, user_name
  FROM profiles
  WHERE id = NEW.user_id;

  -- Make async HTTP request to edge function
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url', true) || '/functions/v1/send-email-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'to', user_email,
      'subject', 'Application Submitted Successfully',
      'html', '<h2>Thank You for Your Application!</h2>' ||
              '<p>Dear ' || COALESCE(user_name, 'Candidate') || ',</p>' ||
              '<p>Your application for the <strong>' || NEW.position || '</strong> position has been received.</p>' ||
              '<p><strong>Application Details:</strong></p>' ||
              '<ul>' ||
              '<li>Position: ' || NEW.position || '</li>' ||
              '<li>Experience: ' || NEW.years_of_experience || ' years</li>' ||
              '<li>Status: ' || NEW.status || '</li>' ||
              '<li>Submitted: ' || to_char(NEW.created_at, 'DD Mon YYYY at HH24:MI') || '</li>' ||
              '</ul>' ||
              '<p>We will review your application and get back to you soon.</p>' ||
              '<p>Best regards,<br>The Hiring Team</p>'
    )
  ) INTO request_id;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the insert
    RAISE WARNING 'Failed to send email notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to notify when status is updated
CREATE OR REPLACE FUNCTION notify_status_updated()
RETURNS TRIGGER AS $$
DECLARE
  user_email text;
  user_name text;
  status_message text;
  request_id bigint;
BEGIN
  -- Only send notification if status actually changed
  IF OLD.status = NEW.status THEN
    RETURN NEW;
  END IF;

  -- Get user details
  SELECT email, full_name INTO user_email, user_name
  FROM profiles
  WHERE id = NEW.user_id;

  -- Create status-specific message
  CASE NEW.status
    WHEN 'shortlisted' THEN
      status_message := '<p>Great news! Your application has been shortlisted. We will contact you soon with next steps.</p>';
    WHEN 'rejected' THEN
      status_message := '<p>After careful consideration, we have decided to move forward with other candidates. We appreciate your interest and wish you the best in your job search.</p>';
    WHEN 'interviewed' THEN
      status_message := '<p>Thank you for attending the interview. We are currently reviewing all candidates and will get back to you soon.</p>';
    ELSE
      status_message := '<p>Your application status has been updated to: <strong>' || NEW.status || '</strong></p>';
  END CASE;

  -- Make async HTTP request to edge function
  SELECT net.http_post(
    url := current_setting('app.settings.supabase_url', true) || '/functions/v1/send-email-notification',
    headers := jsonb_build_object(
      'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
      'to', user_email,
      'subject', 'Application Status Update - ' || NEW.position,
      'html', '<h2>Application Status Update</h2>' ||
              '<p>Dear ' || COALESCE(user_name, 'Candidate') || ',</p>' ||
              '<p>There is an update regarding your application for the <strong>' || NEW.position || '</strong> position.</p>' ||
              status_message ||
              '<p><strong>Application Details:</strong></p>' ||
              '<ul>' ||
              '<li>Position: ' || NEW.position || '</li>' ||
              '<li>Previous Status: ' || OLD.status || '</li>' ||
              '<li>New Status: ' || NEW.status || '</li>' ||
              '<li>Updated: ' || to_char(NEW.updated_at, 'DD Mon YYYY at HH24:MI') || '</li>' ||
              '</ul>' ||
              '<p>Best regards,<br>The Hiring Team</p>'
    )
  ) INTO request_id;

  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    -- Log error but don't fail the update
    RAISE WARNING 'Failed to send email notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for new applications
CREATE TRIGGER on_application_submitted
  AFTER INSERT ON applications
  FOR EACH ROW
  EXECUTE FUNCTION notify_application_submitted();

-- Create trigger for status updates
CREATE TRIGGER on_application_status_updated
  AFTER UPDATE ON applications
  FOR EACH ROW
  EXECUTE FUNCTION notify_status_updated();