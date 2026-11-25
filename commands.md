# Project Dawn — Numbered terminal commands



## Command 1 — Database alias (Terminal 1)

```bash
alias db='docker compose exec -T db psql -U postgres -d commitcourier_dawn_recording -v ON_ERROR_STOP=1'
```

## Command 2 — HTTP helper (Terminal 1)

```bash
api() { local endpoint="$1"; shift; curl -fsS "http://127.0.0.1:8787/api/$endpoint" "$@"; }
```

## Command 3 — JSON POST helper (Terminal 1)

```bash
post() { api "$1" -H 'Content-Type: application/json' -d "$2"; }
```

## Command 4 — Enqueue helper (Terminal 1)

```bash
enqueue() { unset R ID O; R=$(post enqueue "{\"commit\":$1}") && echo "$R" && ID=$(echo "$R" | jq -er '.id | select(type=="string" and length>0)') && O=$(echo "$R" | jq -er '.orderId | select(type=="string" and length>0)'); }
```

## Command 5 — Backend database configuration (Terminal 2)

```bash
node -r dotenv/config -e 'const u=new URL(process.env.DATABASE_URL);console.log(u.host+u.pathname)'
```

## Command 6 — SQL connection and schema (Terminal 1)

```bash
db -c '\conninfo' -c '\d webhook_outbox'
```

## Command 7 — HTTP metrics (Terminal 1)

```bash
api metrics | jq .
```

## Command 8 — Rollback verification (Terminal 1)

```bash
db -c "SELECT id FROM demo_orders WHERE id='$O'; SELECT id FROM webhook_outbox WHERE id='$ID'; TABLE demo_metrics;"
```

## Command 9 — Inspect the current webhook (Terminal 1)

```bash
db -c "SELECT id,status,attempts,created_at FROM webhook_outbox WHERE id='$ID';"
```

## Command 10 — Replay a dead webhook (Terminal 1)

```bash
unset REPLAY_ID; R=$(post replay "{\"outboxId\":\"$DEAD_ID\"}") && echo "$R" && REPLAY_ID=$(echo "$R" | jq -er '.ids[0] | select(type=="string" and length>0)')
```

## Command 11 — Inspect original and replay (Terminal 1)

```bash
db -c "SELECT id,status,attempts,created_at FROM webhook_outbox WHERE id IN ('$DEAD_ID','$REPLAY_ID');"
```

## Command 12 — Both lifetime counter tables (Terminal 1)

```bash
db -c 'TABLE demo_metrics; TABLE demo_heartbeat;'
```

## Command 13 — Failed delivery attempts (Terminal 1)

```bash
api "attempts/$DEAD_ID" | jq '[.[] | {attemptNo,responseStatus,error}]'
```

## Command 14 — Age the successful and dead records (Terminal 1)

```bash
db -c "UPDATE webhook_outbox SET created_at=now()-interval '2 hours' WHERE (id='$GOOD_ID' AND status='delivered') OR (id='$DEAD_ID' AND status='dead');"
```

## Command 15 — Inspect the three retention test records (Terminal 1)

```bash
db -c "SELECT id,status,attempts,created_at FROM webhook_outbox WHERE id IN ('$GOOD_ID','$DEAD_ID','$REPLAY_ID');"
```

## Command 16 — Repeat existing terminal outcomes (Terminal 1)

```bash
db -c "UPDATE webhook_outbox SET status=status WHERE status IN ('delivered','dead');"
```

## Command 17 — Invoke actual one-hour pruning (Terminal 2)

```bash
node --import tsx --input-type=module <<'NODE'
import {buildRelay,pool} from './server/courier.ts';
try {
  const {rows}=await pool.query('SELECT current_database() db');
  console.log(rows);
  if(rows[0].db!=='commitcourier_dawn_recording') throw Error('Wrong database');
  const relay=await buildRelay();
  console.log(await relay.prune({olderThan:new Date(Date.now()-3600000)}));
} finally {
  await pool.end();
}
NODE
```

## Command 18 — Final Git review (Terminal 1)

```bash
git diff --stat && git diff --check
```
