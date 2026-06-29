#!/usr/bin/env sh

set -eu

usage() {
    cat <<'EOF'
Usage: ./build-cv-pdf.sh <language> [output-file]

Languages:
  en       English
  pt       Portuguese (Brazil)
  pt-br    Portuguese (Brazil)

Examples:
  ./build-cv-pdf.sh en
  ./build-cv-pdf.sh pt build/bruno-silva-sette-cv-pt.pdf
EOF
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -lt 1 ] || [ "$#" -gt 2 ]; then
    usage >&2
    exit 1
fi

case "$1" in
    en)
        resume_language="en"
        ;;
    pt|pt-br|pt_BR|pt-BR)
        resume_language="pt"
        ;;
    *)
        echo "Unsupported language: $1" >&2
        echo "Use 'en' or 'pt'." >&2
        exit 1
        ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
source_html="$script_dir/index.html"

if [ ! -f "$source_html" ]; then
    echo "Cannot find index.html next to this script." >&2
    exit 1
fi

if [ "$#" -eq 2 ]; then
    output_pdf=$2
else
    output_pdf="$script_dir/bruno-silva-sette-cv-$resume_language.pdf"
fi

case "$output_pdf" in
    /*) ;;
    *) output_pdf="$script_dir/$output_pdf" ;;
esac

output_dir=$(dirname -- "$output_pdf")
mkdir -p "$output_dir"

browser=""
for candidate in chromium chromium-browser google-chrome google-chrome-stable microsoft-edge microsoft-edge-stable; do
    if command -v "$candidate" >/dev/null 2>&1; then
        browser=$candidate
        break
    fi
done

if [ -z "$browser" ]; then
    echo "Could not find a supported browser." >&2
    echo "Install Chromium or Google Chrome and run this script again." >&2
    exit 1
fi

tmp_dir=$(mktemp -d "$script_dir/.cv-pdf.XXXXXX")
tmp_html="$tmp_dir/cv-$resume_language.html"

cleanup() {
    rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

sed \
    -e '/<\/style>/i\
        @media print {\
            body { background: #ffffff !important; }\
            .language-switch { display: none !important; }\
            footer { display: none !important; }\
            .section:has(.contact-info) { display: none !important; }\
            .section, .header-card { box-shadow: none !important; }\
            a { color: #0f766e !important; }\
        }' \
    -e "s/setLanguage(getStoredLanguage() || 'en');/setLanguage('$resume_language');/" \
    "$source_html" > "$tmp_html"

"$browser" \
    --headless \
    --disable-gpu \
    --no-sandbox \
    --allow-file-access-from-files \
    --no-pdf-header-footer \
    --print-to-pdf="$output_pdf" \
    "file://$tmp_html" >/dev/null

if [ ! -s "$output_pdf" ]; then
    echo "PDF was not created correctly: $output_pdf" >&2
    exit 1
fi

echo "PDF created: $output_pdf"
