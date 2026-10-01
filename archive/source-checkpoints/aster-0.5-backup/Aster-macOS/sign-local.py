#!/usr/bin/env python3
"""Reuse a private development signer so macOS can recognize Aster updates.

This creates a dedicated keychain, never changes certificate trust, and does not
grant any app permissions. Keep its state outside the release and source ZIP.
"""
import hashlib
import os
from pathlib import Path
import secrets
import shlex
import subprocess
import sys
import tempfile


def run(*args):
    result = subprocess.run(args, text=True, capture_output=True)
    if result.returncode:
        # Do not print command arguments: some contain the private keychain password.
        raise RuntimeError(f"{Path(args[0]).name} failed (exit {result.returncode})")
    return result.stdout


def sign(app):
    source = Path(__file__).resolve().parent
    root = Path(os.environ.get("ASTER_SIGNING_DIR", source.parent.parent / ".aster-signing"))
    root.mkdir(parents=True, exist_ok=True, mode=0o700)
    root.chmod(0o700)
    keychain = root / "identity.keychain-db"
    password_file = root / "keychain-password"
    certificate = root / "certificate.pem"
    if not keychain.exists():
        if password_file.exists() or certificate.exists():
            raise RuntimeError("Incomplete signing identity. Restore its keychain before rebuilding.")
        password = secrets.token_urlsafe(48)
        password_file.write_text(password)
        password_file.chmod(0o600)
        original_search_list = shlex.split(run("/usr/bin/security", "list-keychains", "-d", "user"))
        try:
            run("/usr/bin/security", "create-keychain", "-p", password, str(keychain))
        finally:
            # The CLI temporarily adds a created keychain to this list; restore it.
            run("/usr/bin/security", "list-keychains", "-d", "user", "-s", *original_search_list)
        with tempfile.TemporaryDirectory(prefix="prepare-", dir=root) as temporary:
            staging = Path(temporary)
            config = staging / "certificate.cnf"
            config.write_text("""[req]
distinguished_name = subject
x509_extensions = codesign
prompt = no
[subject]
CN = Aster Local Development
O = Aster Personal
[codesign]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
""")
            private_key = staging / "private-key.pem"
            run("/usr/bin/openssl", "req", "-x509", "-newkey", "rsa:3072", "-nodes", "-sha256", "-days", "3650", "-config", str(config), "-keyout", str(private_key), "-out", str(certificate))
            private_key.chmod(0o600)
            package = staging / "identity.p12"
            passfile = staging / "password"
            passfile.write_text(password)
            passfile.chmod(0o600)
            run("/usr/bin/openssl", "pkcs12", "-export", "-inkey", str(private_key), "-in", str(certificate), "-name", "Aster Local Development", "-out", str(package), "-passout", "file:" + str(passfile))
            package.chmod(0o600)
            run("/usr/bin/security", "import", str(package), "-k", str(keychain), "-P", password, "-x", "-T", "/usr/bin/codesign")
            run("/usr/bin/security", "set-key-partition-list", "-S", "apple-tool:,apple:", "-s", "-k", password, str(keychain))
    if not password_file.exists() or not certificate.exists():
        raise RuntimeError("Missing persistent signing material. Restore it before rebuilding.")
    password = password_file.read_text().strip()
    der = subprocess.run(["/usr/bin/openssl", "x509", "-in", str(certificate), "-outform", "DER"], capture_output=True, check=True).stdout
    fingerprint = hashlib.sha1(der).hexdigest().upper()
    run("/usr/bin/security", "unlock-keychain", "-p", password, str(keychain))
    try:
        # Pin both the signing certificate and the app identifier, never just a name.
        requirement = 'designated => identifier "com.aster.desktop" and certificate leaf = H"' + fingerprint + '"'
        run("/usr/bin/codesign", "--force", "--timestamp=none", "--keychain", str(keychain), "--sign", fingerprint, "--requirements", "=" + requirement, str(app))
        run("/usr/bin/codesign", "--verify", "--strict", "--verbose=2", str(app))
    finally:
        run("/usr/bin/security", "lock-keychain", str(keychain))
    print("Aster: persistent local signature verified; system permissions were not changed.")


if __name__ == "__main__":
    try:
        if len(sys.argv) != 2:
            raise RuntimeError("Usage: sign-local.py /path/to/Aster.app")
        sign(Path(sys.argv[1]).resolve())
    except Exception as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
