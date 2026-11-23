# Security notes

Cyber Eye is a **laboratory and educational platform**. It is designed to run inside an isolated network, not on the public internet.

## Before you run it

| Item | Default | What to do |
|---|---|---|
| `.env` | not committed | Copy `.env.example` and set strong, unique values for every password. |
| `alertmanager/alertmanager.yml` | not committed | Copy the example and use an SMTP **app password**, never your account password. |
| Seeded portal user | `web/mysql-init/003_seed_admin.sql` creates `admin` with a development password | Change it or remove the seed file before first start. |
| Fallback admin | `DEFAULT_ADMIN_*` in `.env` (development only) | Use a strong password, or remove the fallback in `web/backend/app.py` for production. |
| Elasticsearch | `xpack.security.enabled=false` | Enable security and TLS outside the lab. |
| Published ports | Elasticsearch, Kibana, Grafana, MySQL, Adminer, Alertmanager | Bind to `127.0.0.1` or firewall them; expose only the portal. |
| CORS | `CORS_ORIGINS` | Restrict to the portal origin. |
| Password hashing | unsalted SHA-256 (database triggers) | Suitable for the lab; use bcrypt / Argon2 for production systems. |

## Responsible use

The attack-simulation tooling described in this project must only be used against systems you own or are explicitly authorised to test.

## Reporting

If you find a security issue in this repository, please open a private security advisory on GitHub instead of a public issue.
