"""Dependency-free static checks; not a substitute for a running Plasma 6 runtime."""
from pathlib import Path
import json
import re
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
meta = json.loads((root / "metadata.json").read_text())
assert meta["KPlugin"]["Id"] == "org.mhpsy.splayernext.lyrics"
assert meta["KPlugin"]["Authors"] == [{"Name": "qssn70"}]
xml = ET.parse(root / "contents/config/main.xml")
key_names = {el.get("name") for el in xml.iter() if el.tag.endswith("entry")}
qml = (root / "contents/ui/main.qml").read_text()
config = (root / "contents/ui/config/ConfigGeneral.qml").read_text()
for prop in re.findall(r"plasmoid\.configuration\.([A-Za-z0-9_]+)", qml):
    assert prop in key_names, f"undefined config property {prop}"
for name in key_names:
    assert "cfg_" + name in config, f"missing configuration field {name}"
compact = (root / "contents/ui/CompactRepresentation.qml").read_text()
assert "Plasmoid.status: root.apiConnected" in qml
assert "PlasmaCore.Types.HiddenStatus" in qml
assert "PlasmaCore.Types.ActiveStatus" in qml
assert "running: true" in qml  # Offline polling must remain enabled for auto-recovery.
assert "visible: apiConnected" in compact
assert "onApiConnectedChanged: { if (!apiConnected) expanded = false }" in qml
assert "if (!apiConnected) return \"\"" in compact
assert "Layout.minimumWidth: apiConnected" in compact
assert "Layout.maximumWidth: apiConnected" in compact
assert "Layout.preferredWidth: apiConnected" in compact
for s in ["/api/now-playing", "/api/lyrics", '"/ws"', "lyricOffsetMs", "sendTimestamp"]:
    assert s in qml, f"missing API field {s}"
code_only = "\n".join(line for line in qml.splitlines() if not line.lstrip().startswith("//"))
for forbidden in ["lrclib", "music.163.com", "/api/control/song-info"]:
    assert forbidden.lower() not in code_only.lower()
for file in list(root.rglob('*.qml')):
    content = file.read_text()
    assert content.count('{') == content.count('}'), f"unbalanced QML braces in {file}"
print("Static checks: passed")

# Plasma 6 requires an explicit package structure on the top-level metadata.
meta = json.loads((root / "metadata.json").read_text(encoding="utf-8"))
assert meta.get("KPackageStructure") == "Plasma/Applet"
assert meta["KPlugin"]["Authors"][0]["Name"] == "qssn70"
