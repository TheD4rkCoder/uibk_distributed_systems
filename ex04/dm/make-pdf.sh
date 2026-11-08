#!/usr/bin/env bash
# Rebuild exc04_report_csbc2382.pdf from README.md.
# Mermaid blocks are rendered to SVG via kroki.io (needs network) and converted to PDF
# with rsvg-convert, then pandoc+xelatex builds the report.
set -euo pipefail
cd "$(dirname "$0")"
out=exc04_report_csbc2382.pdf
build=.pdfbuild
rm -rf "$build" && mkdir -p "$build"
python3 - "$build" <<'PY'
import json, re, subprocess, sys, urllib.request
build = sys.argv[1]
src = open('README.md').read()
pat = re.compile(r'```mermaid\n(.*?)```', re.S)
i = 0
def repl(m):
    global i
    req = urllib.request.Request('https://kroki.io/mermaid/svg',
        data=json.dumps({'diagram_source': m.group(1).strip(), 'diagram_type': 'mermaid',
                         'output_format': 'svg'}).encode(),
        headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
    with urllib.request.urlopen(req, timeout=30) as r:
        svg = f'{build}/diagram{i}.svg'
        open(svg, 'wb').write(r.read())
    pdf = f'{build}/diagram{i}.pdf'
    subprocess.run(['rsvg-convert', '-f', 'pdf', '-o', pdf, svg], check=True)
    i += 1
    return f'![diagram]({pdf}){{width=92%}}'
open(f'{build}/report.md', 'w').write(pat.sub(repl, src))
print(f'rendered {i} mermaid diagrams')
PY
printf '\\usepackage{float}\n\\floatplacement{figure}{H}\n\\usepackage{etoolbox}\n\\AtBeginEnvironment{longtable}{\\small}\n' > "$build/header.tex"
pandoc "$build/report.md" -o "$out" --pdf-engine=xelatex -V geometry:margin=2cm \
	-H "$build/header.tex" --resource-path=".:$build"
rm -rf "$build"
echo "wrote $out"
