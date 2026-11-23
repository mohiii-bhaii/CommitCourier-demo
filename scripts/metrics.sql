
CREATE OR REPLACE FUNCTION track_outbox() RETURNS trigger AS $$
DECLARE m text;
BEGIN
  IF TG_OP='INSERT' THEN m:='enqueued';
  ELSIF OLD.status='in_flight' AND NEW.status='pending' AND NEW.attempts>OLD.attempts THEN m:='retried';
  ELSIF NEW.status IN ('delivered','dead') AND NEW.status<>OLD.status THEN m:=NEW.status; END IF;
  IF m IS NULL OR (m='enqueued' AND NEW.event_type='system.heartbeat') THEN RETURN NEW; END IF;
  EXECUTE format('UPDATE %I SET %I=%I+1 WHERE id=1',CASE WHEN NEW.event_type='system.heartbeat' THEN 'demo_heartbeat' ELSE 'demo_metrics' END,m,m);
  RETURN NEW;
END $$ LANGUAGE plpgsql;
DROP TRIGGER IF EXISTS track_outbox ON webhook_outbox;
CREATE TRIGGER track_outbox AFTER INSERT OR UPDATE OF status,attempts ON webhook_outbox FOR EACH ROW EXECUTE FUNCTION track_outbox();
ALTER TABLE demo_metrics ADD COLUMN IF NOT EXISTS verified_since timestamptz DEFAULT now();
ALTER TABLE demo_heartbeat ADD COLUMN IF NOT EXISTS verified_since timestamptz DEFAULT now();
