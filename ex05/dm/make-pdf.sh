#!/usr/bin/env bash
# Rebuild exc05_report_csbc2382.pdf from README.md (pandoc + xelatex).
set -euo pipefail
cd "$(dirname "$0")"
out=exc05_report_csbc2382.pdf
build=.pdfbuild
rm -rf "$build" && mkdir -p "$build"
printf '\\usepackage{float}\n\\floatplacement{figure}{H}\n\\usepackage{etoolbox}\n\\AtBeginEnvironment{longtable}{\\small}\n\\usepackage{fancyvrb}\n\\AtBeginEnvironment{Verbatim}{\\footnotesize}\n' > "$build/header.tex"
pandoc README.md -o "$out" --pdf-engine=xelatex -V geometry:margin=2cm \
	-H "$build/header.tex" --resource-path=".:$build"
rm -rf "$build"
echo "wrote $out"
