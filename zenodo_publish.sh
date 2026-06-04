#!/usr/bin/env bash
# ============================================================
# Zenodo Publish Template (v1.0)
# Usage: export ZENODO_TOKEN=<token> && bash zenodo_publish.sh
# ============================================================
set -euo pipefail

if [ -z "${ZENODO_TOKEN:-}" ]; then
  echo "Error: ZENODO_TOKEN environment variable is not set."
  echo "Export it before running: export ZENODO_TOKEN=\$(cat /path/to/zenodo.txt)"
  exit 1
fi
TOKEN="$ZENODO_TOKEN"
BASE="https://zenodo.org/api"

# ---- EDIT THESE ----
PROJECT_NAME="community-skills"
VERSION="0.2.0"
DESCRIPTION="community-skills v0.2.0: an R-focused hub of agent-callable skills for the CRAN ecosystem. 110 skills total (5 core + 105 R); cran_publisher with CRAN and r-universe channels; harness sister package for role-curated agent sessions."
# --------------------

echo "=== Step 1: Create empty deposit ==="
DEPOSIT=$(curl -s -X POST "$BASE/deposit/depositions" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}')

DEPOSIT_ID=$(echo "$DEPOSIT" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])")
echo "Deposit created with ID: $DEPOSIT_ID"

echo ""
echo "=== Step 2: Set metadata ==="
METADATA_JSON=$(python3 << PYEOF
import json
with open('.zenodo.json') as f:
    zj = json.load(f)
data = {
    'metadata': {
        'title': zj['title'],
        'version': '$VERSION',
        'description': """$DESCRIPTION""",
        'upload_type': zj.get('upload_type', 'software'),
        'publication_date': '$(date +%Y-%m-%d)',
        'creators': zj['creators'],
        'keywords': zj.get('keywords', []),
        'license': zj.get('license', 'CC-BY-NC-SA-4.0').lower(),
        'access_right': 'open',
        'related_identifiers': [
            {
                'identifier': 'https://github.com/pcbrom/$PROJECT_NAME',
                'relation': 'isSupplementTo',
                'resource_type': 'software',
                'scheme': 'url'
            }
        ],
        'notes': zj.get('references', [''])[0] if zj.get('references') else ''
    }
}
print(json.dumps(data))
PYEOF
)

curl -s -X PUT "$BASE/deposit/depositions/$DEPOSIT_ID" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$METADATA_JSON" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Title:', d.get('metadata',{}).get('title','?')); print('PrereserveDOI:', d.get('metadata',{}).get('prereserve_doi',{}).get('doi','N/A'))"

echo ""
echo "=== Step 3: Create zip of repository (git-tracked files only) ==="
cd "$(dirname "$0")"
ZIP_NAME="${PROJECT_NAME}-${VERSION}.zip"
git archive --format=zip --prefix="${PROJECT_NAME}-${VERSION}/" -o "/tmp/$ZIP_NAME" HEAD
echo "Created /tmp/$ZIP_NAME ($(du -h /tmp/$ZIP_NAME | cut -f1))"

echo ""
echo "=== Step 4: Upload zip file ==="
BUCKET_URL=$(echo "$DEPOSIT" | python3 -c "import sys,json; print(json.load(sys.stdin)['links']['bucket'])")
curl -s -X PUT "$BUCKET_URL/$ZIP_NAME" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/octet-stream" \
  --data-binary "@/tmp/$ZIP_NAME" | python3 -c "import sys,json; d=json.load(sys.stdin); print('Uploaded:', d.get('key','?'), '- Size:', d.get('size','?'), 'bytes')"

echo ""
echo "============================================"
echo "=== REVIEW BEFORE PUBLISHING ==="
echo "============================================"
echo ""
echo "Draft URL: https://zenodo.org/deposit/$DEPOSIT_ID"
echo ""
echo "Open the URL above in your browser to review."
echo ""
read -p "Publish this deposit? (y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
  RESULT=$(curl -s -X POST "$BASE/deposit/depositions/$DEPOSIT_ID/actions/publish" \
    -H "Authorization: Bearer $TOKEN")
  NEW_DOI=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['doi'])" 2>/dev/null || echo "check Zenodo")
  CONCEPT_DOI=$(echo "$RESULT" | python3 -c "import sys,json; print(json.load(sys.stdin)['conceptdoi'])" 2>/dev/null || echo "check Zenodo")
  echo ""
  echo "Published!"
  echo "   Version DOI: $NEW_DOI"
  echo "   Concept DOI: $CONCEPT_DOI"
  echo ""
  echo "   IMPORTANT: Update these files with the new DOIs:"
  echo "   - README.md (badge and citation)"
  echo "   - .zenodo.json (if needed)"
else
  echo ""
  echo "Draft saved but NOT published."
  echo "Edit/publish manually at: https://zenodo.org/deposit/$DEPOSIT_ID"
fi

# Cleanup
rm -f "/tmp/$ZIP_NAME"
echo ""
echo "Done."
