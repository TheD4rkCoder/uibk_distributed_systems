#!/usr/bin/env bash
# Rebuild exc03_report_csbc2382.pdf from README.md.
# Mermaid blocks are rendered to PNG via kroki.io (needs network), then pandoc+xelatex.
set -euo pipefail
cd "$(dirname "$0")"
out=exc03_report_csbc2382.pdf
build=.pdfbuild
rm -rf "$build" && mkdir -p "$build"
python3 - "$build" <<'PY'
import json, re, sys, urllib.request
build = sys.argv[1]
src = open('README.md').read()
pat = re.compile(r'```mermaid\n(.*?)```', re.S)
i = 0
def repl(m):
    global i
    req = urllib.request.Request('https://kroki.io/mermaid/png',
        data=json.dumps({'diagram_source': m.group(1).strip(), 'diagram_type': 'mermaid',
                         'output_format': 'png'}).encode(),
        headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=30) as r:
        data = r.read()
    path = f'{build}/diagram{i}.png'
    open(path, 'wb').write(data)
    i += 1
    return f'![diagram]({path}){{width=92%}}'
open(f'{build}/report.md', 'w').write(pat.sub(repl, src))
print(f'rendered {i} mermaid diagrams')
PY
pandoc "$build/report.md" -o "$out" --pdf-engine=xelatex -V geometry:margin=2cm
rm -rf "$build"
echo "wrote $out"
