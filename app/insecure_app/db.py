import os
import psycopg2
import psycopg2.extras
from dotenv import load_dotenv

load_dotenv()

def get_connection():
    """
    INSECURE VERSION: always connects as the postgres superuser.
    This means the database itself places NO limits on what any
    logged-in app user can query -- all control is (weakly) in Python.
    """
    conn = psycopg2.connect(
        host=os.getenv("DB_HOST"),
        port=os.getenv("DB_PORT"),
        dbname=os.getenv("DB_NAME"),
        user=os.getenv("DB_SUPERUSER"),
        password=os.getenv("DB_SUPERUSER_PASSWORD"),
    )
    return conn

def query(sql, params=None, fetch=True):
    conn = get_connection()
    cur = conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor)
    cur.execute(sql, params or ())
    result = cur.fetchall() if fetch else None
    conn.commit()
    cur.close()
    conn.close()
    return result
