
BEGIN;
DO $$
DECLARE x uuid:=gen_random_uuid(); y uuid:=gen_random_uuid(); h uuid:=gen_random_uuid(); a demo_metrics%ROWTYPE; b demo_metrics%ROWTYPE; c bigint;
BEGIN
  SELECT * INTO a FROM demo_metrics WHERE id=1 FOR UPDATE;
  SELECT delivered INTO c FROM demo_heartbeat WHERE id=1 FOR UPDATE;
  INSERT INTO webhook_outbox(id,event_type,payload,target_url,status) VALUES
    (x,'order.created','{}','http://127.0.0.1:8787/receiver','pending'),
    (y,'order.created','{}','http://127.0.0.1:8787/receiver','pending'),
    (h,'system.heartbeat','{}','http://127.0.0.1:8787/receiver','pending');
  UPDATE webhook_outbox SET status='in_flight' WHERE id IN (x,y,h);
  UPDATE webhook_outbox SET status='pending',attempts=1 WHERE id=x;
  UPDATE webhook_outbox SET status='in_flight' WHERE id=x;
  UPDATE webhook_outbox SET status='delivered' WHERE id IN (x,h);
  UPDATE webhook_outbox SET status='delivered' WHERE id=x;
  UPDATE webhook_outbox SET status='dead',attempts=1 WHERE id=y;
  DELETE FROM webhook_outbox WHERE id IN (x,y,h);
  SELECT * INTO b FROM demo_metrics WHERE id=1;
  IF (b.enqueued-a.enqueued,b.retried-a.retried,b.delivered-a.delivered,b.dead-a.dead) IS DISTINCT FROM (2,1,1,1)
    OR (SELECT delivered FROM demo_heartbeat WHERE id=1)<>c+1 THEN RAISE EXCEPTION 'Metric mismatch'; END IF;
  RAISE NOTICE 'PASS: enqueue, retry, delivery, dead, duplicate, heartbeat, deletion'; END $$;
ROLLBACK;
