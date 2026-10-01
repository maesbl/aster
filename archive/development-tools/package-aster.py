from pathlib import Path
import os, re, shutil, stat, subprocess, tempfile, zipfile
root = Path(__file__).resolve().parent.parent
outputs = root / "outputs"
secret_text = (root / ".env.local").read_text()
match = re.search(r"(?m)^OPENAI_API_KEY\s*=\s*[\"\']?([^\s\"\']+)", secret_text)
secret = match.group(1).encode() if match else None
assert secret, "Local connection is missing"
files = []
for folder in [outputs / "Aster.app", outputs / "Aster-macOS"]:
    files += [path for path in folder.rglob("*") if path.is_file() and "__pycache__" not in path.parts and path.name != ".DS_Store"]
for name in ["Aster-a-tu-lado.png", "Aster-actividad.png", "Aster-investigacion-y-capacidades.md", "Aster-logo.png", "Aster-logo-en-macOS.png", "Aster-interfaz.png", "Aster-minichat.png", "Aster-minichat-respuesta.png", "Aster-voz.mp3", "Aster-control-prueba.txt", "Aster-primer-plan.md"]:
    path = outputs / name
    if path.exists(): files.append(path)
private_names = {"keychain-password", "identity.keychain-db", "private-key.pem", "identity.p12", ".env.local"}
for path in files:
    assert not set(path.parts).intersection(private_names), "Private signing material found"
    assert secret not in path.read_bytes(), "A credential was found in a deliverable"
tempzip = outputs / "Aster-macOS.zip.tmp"
with zipfile.ZipFile(tempzip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for path in sorted(files): archive.write(path, path.relative_to(outputs))
with zipfile.ZipFile(tempzip) as archive:
    assert archive.testzip() is None
    executable = archive.getinfo("Aster.app/Contents/MacOS/Aster")
    assert ((executable.external_attr >> 16) & stat.S_IXUSR) != 0
    with tempfile.TemporaryDirectory(prefix="aster-package-check-", dir=root / "work") as tmp:
        for member in archive.infolist():
            if member.filename.startswith("Aster.app/"):
                archive.extract(member, tmp)
                os.chmod(Path(tmp) / member.filename, member.external_attr >> 16)
        subprocess.run(["codesign", "--verify", "--strict", str(Path(tmp) / "Aster.app")], check=True, capture_output=True)
os.replace(tempzip, outputs / "Aster-macOS.zip")
print(f"Aster 0.5.0 packaged: {len(files)} files, executable preserved, extracted signature verified, no local credential or private signer included.")
