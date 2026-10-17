#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"
if ! command -v kpackagetool6 >/dev/null 2>&1; then
    echo "kpackagetool6 not found. Install KDE Plasma 6 packaging tools." >&2
    exit 1
fi
id='org.mhpsy.splayernext.lyrics'
installed="$HOME/.local/share/plasma/plasmoids/$id"
# v1.1.0/v1.1.1 accidentally omitted KPackageStructure. Repair only our own
# local manifest first, or kpackagetool6 -u will incorrectly say not installed.
if [ -f "$installed/metadata.json" ]; then
    python3 - "$installed/metadata.json" <<'PYFIX'
import json, sys
from pathlib import Path
path = Path(sys.argv[1])
meta = json.loads(path.read_text(encoding='utf-8'))
if meta.get('KPlugin', {}).get('Id') != 'org.mhpsy.splayernext.lyrics':
    raise SystemExit('Unexpected widget ID, refusing to edit installed metadata')
if meta.get('KPackageStructure') != 'Plasma/Applet':
    meta['KPackageStructure'] = 'Plasma/Applet'
    path.write_text(json.dumps(meta, ensure_ascii=False, indent=4) + '\n', encoding='utf-8')
    print('Repaired the old Plasma 6 package metadata (kept existing settings).')
PYFIX
    kpackagetool6 -t Plasma/Applet -u .
else
    kpackagetool6 -t Plasma/Applet -i .
fi
echo 'Music Lyrics v1.3.0 installed. Log out/in if Plasma does not reload it.'
