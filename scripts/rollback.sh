#!/bin/bash
# Rolls back the app container to the previous git commit's image.
set -e

PREVIOUS_COMMIT=$(git log --oneline -2 | tail -1 | awk '{print $1}')

echo "Current commit : $(git log --oneline -1)"
echo "Rolling back to: $PREVIOUS_COMMIT"
echo ""

read -r -p "Continue? [y/N] " confirm
[[ "$confirm" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }

echo "Stopping stack..."
docker compose down

echo "Checking out previous app version ($PREVIOUS_COMMIT)..."
git checkout "$PREVIOUS_COMMIT" -- app/

echo "Rebuilding and restarting..."
docker compose up --build -d

echo ""
echo "Rollback complete. Run 'docker compose ps' to verify service health."
echo "To undo this rollback: git checkout HEAD -- app/ && docker compose up --build -d"
