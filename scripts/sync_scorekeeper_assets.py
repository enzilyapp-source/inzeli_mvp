#!/usr/bin/env python3
"""Refresh reviewed offline engines from ../Qaid; preserve native-only adapters.
Run the website and embedded tests after syncing. This does not deploy either app.
"""
from pathlib import Path
import shutil
import subprocess
import json

app = Path(__file__).resolve().parents[1]
source = app.parent / 'Qaid'
dest = app / 'lib/assets/scorekeeper'
files = sorted(p for p in source.iterdir() if p.suffix in {'.html', '.css', '.js'})
for file in files:
    shutil.copy2(file, dest / file.name)
commit = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
(dest / 'source.json').write_text(json.dumps({'repository': 'enzilyapp-source/Qaed', 'commit': commit,
    'files': [p.name for p in files]}, indent=2) + '\n')
print(f'Synced {len(files)} website assets at {commit[:7]}; native adapters preserved.')
