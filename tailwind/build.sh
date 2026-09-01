#!/bin/sh
# Regenerate the purged Tailwind stylesheet (assets/app.css) from the utility
# classes used in assets/index.html and assets/app.js. Run from the project root
# after changing any Tailwind classes.
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
npx -y tailwindcss@3.4.17 -c tailwind/tailwind.config.js -i tailwind/input.css -o assets/app.css --minify
echo "wrote assets/app.css"
