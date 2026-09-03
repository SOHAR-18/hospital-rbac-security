import os
import bcrypt
from flask import Flask, render_template, request, redirect, url_for, session, flash
from dotenv import load_dotenv
from db import query

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY")


def login_required(f):
    """Basic check: is *someone* logged in? Does NOT check role."""
    from functools import wraps
    @wraps(f)
    def wrapper(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return wrapper


@app.route("/")
def home():
    if "user_id" in session:
        return redirect(url_for("dashboard"))
    return redirect(url_for("login"))


@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        username = request.form["username"]
        password = request.form["password"]

        result = query("SELECT * FROM users WHERE username = %s", (username,))
        if result:
            user = result[0]
            if bcrypt.checkpw(password.encode(), user["password_hash"].encode()):
                session["user_id"] = user["user_id"]
                session["username"] = user["username"]
                session["role"] = user["role"]
                session["linked_id"] = user["linked_id"]
                session["full_name"] = user["full_name"]
                flash(f"Welcome, {user['full_name']}!", "success")
                return redirect(url_for("dashboard"))
        flash("Invalid username or password.", "danger")
    return render_template("login.html")


@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("login"))


@app.route("/dashboard")
@login_required
def dashboard():
    return render_template("dashboard.html")


# ------------------------------------------------------------------
# PATIENTS LIST
# App-level check: only admin/doctor/nurse/receptionist should see this.
# (This check IS present and correct here.)
# ------------------------------------------------------------------
@app.route("/patients")
@login_required
def patients():
    if session["role"] not in ("admin", "doctor", "nurse", "receptionist"):
        flash("Access denied.", "danger")
        return redirect(url_for("dashboard"))
    rows = query("SELECT * FROM patients ORDER BY patient_id")
    return render_template("patients.html", patients=rows)


# ------------------------------------------------------------------
# VULNERABILITY #1: SQL INJECTION
# Patient search builds a raw SQL string using string formatting
# instead of a parameterized query. This is a classic, common
# real-world mistake -- looks convenient, is exploitable.
# ------------------------------------------------------------------
@app.route("/search", methods=["GET", "POST"])
@login_required
def search():
    results = []
    search_term = ""
    if request.method == "POST":
        search_term = request.form["name"]
        # VULNERABLE: never do this -- string-built SQL
        sql = f"SELECT * FROM patients WHERE full_name ILIKE '%{search_term}%'"
        results = query(sql)
    return render_template("search.html", results=results, search_term=search_term)


# ------------------------------------------------------------------
# VULNERABILITY #2: IDOR (Insecure Direct Object Reference)
# Any logged-in user can view ANY medical record by changing the
# record_id in the URL. The code checks "are you logged in?" but
# forgets to check "do you actually own or need this record?"
# ------------------------------------------------------------------
@app.route("/medical-records/<int:record_id>")
@login_required
def medical_record_detail(record_id):
    # BUG: no check that session["role"] is doctor/nurse,
    # and no check that this doctor is assigned to this patient.
    rows = query(
        """SELECT mr.*, p.full_name AS patient_name, d.full_name AS doctor_name
           FROM medical_records mr
           JOIN patients p ON p.patient_id = mr.patient_id
           JOIN doctors d ON d.doctor_id = mr.doctor_id
           WHERE mr.record_id = %s""",
        (record_id,),
    )
    if not rows:
        flash("Record not found.", "warning")
        return redirect(url_for("dashboard"))
    return render_template("record_detail.html", record=rows[0])


@app.route("/medical-records")
@login_required
def medical_records_list():
    # Intended for doctor/nurse only -- but again, no ownership check
    # even for doctors: a doctor sees ALL records, not just their own.
    if session["role"] not in ("admin", "doctor", "nurse"):
        flash("Access denied.", "danger")
        return redirect(url_for("dashboard"))
    rows = query(
        """SELECT mr.record_id, mr.diagnosis, p.full_name AS patient_name,
                  d.full_name AS doctor_name, mr.record_date
           FROM medical_records mr
           JOIN patients p ON p.patient_id = mr.patient_id
           JOIN doctors d ON d.doctor_id = mr.doctor_id
           ORDER BY mr.record_id"""
    )
    return render_template("records_list.html", records=rows)


# ------------------------------------------------------------------
# BILLING -- app-level check present and correct here
# ------------------------------------------------------------------
@app.route("/billing")
@login_required
def billing():
    if session["role"] not in ("admin", "billing_clerk"):
        flash("Access denied.", "danger")
        return redirect(url_for("dashboard"))
    rows = query(
        """SELECT b.*, p.full_name AS patient_name
           FROM billing b JOIN patients p ON p.patient_id = b.patient_id
           ORDER BY b.bill_id"""
    )
    return render_template("billing.html", bills=rows)


if __name__ == "__main__":
    app.run(debug=True, port=5000)
