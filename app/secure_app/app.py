import os
import bcrypt
import psycopg2.errors
from flask import Flask, render_template, request, redirect, url_for, session, flash
from dotenv import load_dotenv
from db import auth_query, role_query

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("SECRET_KEY")


def login_required(f):
    from functools import wraps
    @wraps(f)
    def wrapper(*args, **kwargs):
        if "user_id" not in session:
            return redirect(url_for("login"))
        return f(*args, **kwargs)
    return wrapper


def current_doctor_id():
    """Only meaningful when session['role'] == 'doctor'."""
    return session.get("linked_id")


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

        # Login step uses the minimal-privilege auth role --
        # this connection can ONLY read the users table, nothing else.
        result = auth_query("SELECT * FROM users WHERE username = %s", (username,))
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


# ------------------------------------------------------------
# PATIENTS
# Note: NO manual filtering in Python for doctors -- RLS does
# that automatically based on the role_query() connection.
# ------------------------------------------------------------
@app.route("/patients")
@login_required
def patients():
    try:
        rows = role_query(
            session["role"],
            "SELECT * FROM patients ORDER BY patient_id",
            doctor_id=current_doctor_id(),
        )
    except psycopg2.errors.InsufficientPrivilege:
        flash("Access denied by the database: your role has no privilege on this table.", "danger")
        return redirect(url_for("dashboard"))
    return render_template("patients.html", patients=rows)


# ------------------------------------------------------------
# SEARCH -- now fully parameterized, SQL injection is impossible
# regardless of what the user types.
# ------------------------------------------------------------
@app.route("/search", methods=["GET", "POST"])
@login_required
def search():
    results = []
    search_term = ""
    if request.method == "POST":
        search_term = request.form["name"]
        try:
            results = role_query(
                session["role"],
                "SELECT * FROM patients WHERE full_name ILIKE %s ORDER BY patient_id",
                (f"%{search_term}%",),
                doctor_id=current_doctor_id(),
            )
        except psycopg2.errors.InsufficientPrivilege:
            flash("Access denied by the database.", "danger")
    return render_template("search.html", results=results, search_term=search_term)


# ------------------------------------------------------------
# MEDICAL RECORD DETAIL -- deliberately SAME shape as the
# insecure app's route (no Python role check!) to prove the
# database itself now blocks what the app forgets to check.
# ------------------------------------------------------------
@app.route("/medical-records/<int:record_id>")
@login_required
def medical_record_detail(record_id):
    try:
        rows = role_query(
            session["role"],
            """SELECT mr.*, p.full_name AS patient_name, d.full_name AS doctor_name
               FROM medical_records mr
               JOIN patients p ON p.patient_id = mr.patient_id
               JOIN doctors d ON d.doctor_id = mr.doctor_id
               WHERE mr.record_id = %s""",
            (record_id,),
            doctor_id=current_doctor_id(),
        )
    except psycopg2.errors.InsufficientPrivilege:
        flash("Access denied by the database: your role cannot view medical records.", "danger")
        return redirect(url_for("dashboard"))

    if not rows:
        flash("Record not found (or not visible to your role/account).", "warning")
        return redirect(url_for("dashboard"))
    return render_template("record_detail.html", record=rows[0])


@app.route("/medical-records")
@login_required
def medical_records_list():
    try:
        rows = role_query(
            session["role"],
            """SELECT mr.record_id, mr.diagnosis, p.full_name AS patient_name,
                      d.full_name AS doctor_name, mr.record_date
               FROM medical_records mr
               JOIN patients p ON p.patient_id = mr.patient_id
               JOIN doctors d ON d.doctor_id = mr.doctor_id
               ORDER BY mr.record_id""",
            doctor_id=current_doctor_id(),
        )
    except psycopg2.errors.InsufficientPrivilege:
        flash("Access denied by the database: your role cannot view medical records.", "danger")
        return redirect(url_for("dashboard"))
    return render_template("records_list.html", records=rows)


# ------------------------------------------------------------
# BILLING
# ------------------------------------------------------------
@app.route("/billing")
@login_required
def billing():
    try:
        rows = role_query(
            session["role"],
            """SELECT b.*, p.full_name AS patient_name
               FROM billing b JOIN patients p ON p.patient_id = b.patient_id
               ORDER BY b.bill_id""",
            doctor_id=current_doctor_id(),
        )
    except psycopg2.errors.InsufficientPrivilege:
        flash("Access denied by the database: your role cannot view billing.", "danger")
        return redirect(url_for("dashboard"))
    return render_template("billing.html", bills=rows)


if __name__ == "__main__":
    app.run(debug=True, port=5001)  # different port so you can run both apps side by side
