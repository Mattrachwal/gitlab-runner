# Runner Admin (Optional)

Local-only admin UI for your runner host.

## Endpoints

- `GET /health`
- `GET /config` (tokens masked)
- `POST /config` (write config.json)
- `POST /apply/concurrent`
- `POST /apply/register`
- `POST /runner/restart`
- `GET /runner/list`

## Auth

Basic auth via `.env` (`ADMIN_USER`, `ADMIN_PASS`).
