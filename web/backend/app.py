from flask import Flask, request, jsonify
from flask_cors import CORS
import pymysql  # type: ignore
import hashlib
import time
import os


try:
    from dotenv import load_dotenv  # type: ignore
    load_dotenv()
except Exception:
    pass


def env(name: str, default: str | None = None) -> str:
    val = os.getenv(name, default)
    return "" if val is None else val


def sha256_hex(s: str) -> str:
    return hashlib.sha256(s.encode("utf-8")).hexdigest()


app = Flask(__name__)

# ==============================
# CORS
# ==============================

cors_origins = [o.strip() for o in env("CORS_ORIGINS", "*").split(",") if o.strip()]
if cors_origins == ["*"]:
    CORS(app)  # allow all (dev)
else:
    CORS(app, resources={r"/*": {"origins": cors_origins}})

# ==============================
# Database Configuration (from env)
# ==============================
db_config = {
    "host": env("DB_HOST", "mysql"),
    "user": env("DB_USER", "root"),
    "password": env("DB_PASSWORD", ""),
    "database": env("DB_NAME", "cyber_eye"),
    "charset": env("DB_CHARSET", "utf8mb4"),
    "port": int(env("DB_PORT", "3306")),
}

# ==============================
# Default Admin (DEV ONLY) - from env
# ==============================
DEFAULT_ADMIN_USER = env("DEFAULT_ADMIN_USER", "admin").strip()
DEFAULT_ADMIN_PASSWORD = env("DEFAULT_ADMIN_PASSWORD", "admin123")
DEFAULT_ADMIN_EMAIL = env("DEFAULT_ADMIN_EMAIL", "admin@cybereye.local")
DEFAULT_ADMIN_PASSWORD_HASH = sha256_hex(DEFAULT_ADMIN_PASSWORD)

# ==============================
# SMTP Settings (Alerts) - from env (kept here for future use)
# ==============================
SMTP_SMARTHOST = env("SMTP_SMARTHOST", "smtp.gmail.com:587")
SMTP_FROM = env("SMTP_FROM", "")
SMTP_USER = env("SMTP_USER", "")
SMTP_PASS = env("SMTP_PASS", "")
ALERT_TO = env("ALERT_TO", "")

# ==============================
# Grafana Admin (kept here for env linkage)
# ==============================
GF_ADMIN_PASSWORD = env("GF_ADMIN_PASSWORD", "admin")


def get_db_connection(retries: int = 5, delay: int = 2):
    last_error = None

    for attempt in range(1, retries + 1):
        try:
            print(f"[DB] Trying to connect (attempt {attempt}/{retries})...")
            conn = pymysql.connect(
                host=db_config["host"],
                user=db_config["user"],
                password=db_config["password"],
                database=db_config["database"],
                charset=db_config["charset"],
                port=db_config["port"],
                cursorclass=pymysql.cursors.DictCursor,
            )
            print("[DB] Connection established.")
            return conn
        except Exception as e:
            last_error = e
            print(f"[DB] Connection attempt {attempt} failed: {e!r}")
            if attempt < retries:
                time.sleep(delay)

    raise last_error if last_error else Exception("Unknown DB connection error")


@app.route("/", methods=["GET"])
def home():
    return "CYBER EYE API is running", 200


@app.route("/health", methods=["GET"])
def health():
    
    return jsonify({"status": "ok"}), 200



@app.route("/health/db", methods=["GET"])
def health_db():
    try:
        conn = get_db_connection(retries=1, delay=0)
        try:
            with conn.cursor() as cur:
                cur.execute("SELECT 1 AS ok")
                cur.fetchone()
        finally:
            conn.close()

        return jsonify({"status": "ok", "db": "connected"}), 200
    except Exception as e:
        return jsonify({"status": "error", "db": "unreachable", "message": str(e)}), 500


@app.route("/login", methods=["POST"])
def login():
    print(">>> /login called")

    data = request.get_json(silent=True) or {}
    username = (data.get("username") or "").strip()
    password = data.get("password") or ""

    if not username or not password:
        return jsonify({"success": False, "message": "Username and password are required"}), 400

    password_sha256 = sha256_hex(password)

    # ==============================
    # 1) Try Database Login
    # ==============================
    user = None
    try:
        conn = get_db_connection()
        try:
            with conn.cursor() as cur:
                query = """
                    SELECT id, username, email, password_hash
                    FROM users
                    WHERE username = %s OR email = %s
                    LIMIT 1
                """
                cur.execute(query, (username, username))
                user = cur.fetchone()
        finally:
            conn.close()
    except Exception as e:
        print("DB error in /login:", e)
        user = None

    if user:
        if password_sha256 != (user.get("password_hash") or ""):
            return jsonify({"success": False, "message": "Invalid username or password"}), 401

        return jsonify({
            "success": True,
            "message": "Login successful",
            "user": {
                "id": user["id"],
                "username": user["username"],
                "email": user["email"],
                "source": "database",
            }
        }), 200

    # ==============================
    # 2) Default Admin Fallback (DEV)
    # ==============================
    if username == DEFAULT_ADMIN_USER and password_sha256 == DEFAULT_ADMIN_PASSWORD_HASH:
        return jsonify({
            "success": True,
            "message": "Login successful (default admin)",
            "user": {
                "id": 0,
                "username": DEFAULT_ADMIN_USER,
                "email": DEFAULT_ADMIN_EMAIL,
                "source": "default_admin",
            }
        }), 200

    return jsonify({"success": False, "message": "Invalid username or password"}), 401


if __name__ == "__main__":
    host = env("FLASK_HOST", "0.0.0.0")
    port = int(env("FLASK_PORT", "5000"))
    debug = env("FLASK_DEBUG", "false").lower() == "true"
    app.run(host=host, port=port, debug=debug)
