import os
import psycopg2
import psycopg2.extras
import psycopg2.errors
from dotenv import load_dotenv

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")

# ------------------------------------------------------------
# Maps each APP-LEVEL role (stored in users.role) to the actual
# PostgreSQL login role + password created in Phase 5.
# In a real system these passwords would come from a secrets
# manager, never hardcoded -- fine for a demo/project.
# ------------------------------------------------------------
ROLE_CREDENTIALS = {
    "admin":         ("admin_role",        "AdminRole@123"),
    "doctor":        ("doctor_role",       "DoctorRole@123"),
    "nurse":         ("nurse_role",        "NurseRole@123"),
    "receptionist":  ("receptionist_role", "ReceptionRole@123"),
    "billing_clerk": ("billing_role",      "BillingRole@123"),
}

AUTH_USER = "app_auth_role"
AUTH_PASSWORD = "AuthRole@123"


def get_auth_connection():
    """Minimal-privilege connection used ONLY to verify login credentials."""
    return psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=AUTH_USER, password=AUTH_PASSWORD,
    )


def get_role_connection(app_role, doctor_id=None):
    """
    Opens a connection AS THE ACTUAL POSTGRESQL ROLE matching this
    user's app-level role. If this is a doctor, also sets the
    session variable that Phase 6's RLS policies key off of.
    """
    if app_role not in ROLE_CREDENTIALS:
        raise ValueError(f"No database role mapped for app role: {app_role}")

    db_user, db_password = ROLE_CREDENTIALS[app_role]
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, dbname=DB_NAME,
        user=db_user, password=db_password,
    )
    if app_role == "doctor" and doctor_id is not None:
        cur = conn.cursor()
        # doctor_id comes from our own users table (trusted, not user input),
        # but we still validate it's an int before using it in SET.
        cur.execute("SET app.current_doctor_id = %s", (str(int(doctor_id)),))
        cur.close()
    return conn


def auth_query(sql, params=None):
    """Run a query using the minimal-privilege auth role (login step only)."""
    conn = get_auth_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(sql, params or ())
    result = cur.fetchall()
    conn.commit()
    cur.close()
    conn.close()
    return result


def log_event(username, action, table_name, success, detail=""):
    """
    Writes a row to audit_log using the auth role (it has INSERT
    rights on audit_log from Phase 7's setup script). Used to
    record both successful and DENIED access attempts.
    """
    conn = get_auth_connection()
    cur = conn.cursor()
    cur.execute(
        """INSERT INTO audit_log (username, action, table_name, success, detail)
           VALUES (%s, %s, %s, %s, %s)""",
        (username, action, table_name, success, detail),
    )
    conn.commit()
    cur.close()
    conn.close()


def role_query(app_role, sql, params=None, doctor_id=None, fetch=True):
    """
    Run a query AS the real PostgreSQL role for this app role.
    This is what makes GRANT/REVOKE + RLS actually apply --
    if the role lacks privilege, psycopg2.errors.InsufficientPrivilege
    is raised, which routes handle gracefully (see app.py).
    """
    conn = get_role_connection(app_role, doctor_id=doctor_id)
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    if params is not None:
        cur.execute(sql, params)
    else:
        cur.execute(sql)
    result = cur.fetchall() if fetch else None
    conn.commit()
    cur.close()
    conn.close()
    return result
