"""
Run this ONCE after Phase 2 to replace the PLACEHOLDER passwords
with real bcrypt hashes. All demo users get the password: Passw0rd!
(You'd never do this in a real system -- this is purely so everyone
in your demo/presentation can log in with one memorable password.)

Run from the insecure_app folder:
    python set_passwords.py
"""
import bcrypt
from db import query

DEMO_PASSWORD = "Passw0rd!"

def main():
    hashed = bcrypt.hashpw(DEMO_PASSWORD.encode(), bcrypt.gensalt()).decode()
    users = query("SELECT username FROM users")
    for u in users:
        query(
            "UPDATE users SET password_hash = %s WHERE username = %s",
            (hashed, u["username"]),
            fetch=False,
        )
        print(f"Updated password for {u['username']}")
    print(f"\nAll users can now log in with password: {DEMO_PASSWORD}")

if __name__ == "__main__":
    main()
