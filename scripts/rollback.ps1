# Rolls back the app container to the previous git commit's image.
$ErrorActionPreference = "Stop"

$previousCommit = (git log --oneline -2 | Select-Object -Last 1).Split(" ")[0]

Write-Host "Current commit : $(git log --oneline -1)"
Write-Host "Rolling back to: $previousCommit"
Write-Host ""

$confirm = Read-Host "Continue? [y/N]"
if ($confirm -notmatch '^[Yy]$') { Write-Host "Aborted."; exit 0 }

Write-Host "Stopping stack..."
docker compose down

Write-Host "Checking out previous app version ($previousCommit)..."
git checkout $previousCommit -- app/

Write-Host "Rebuilding and restarting..."
docker compose up --build -d

Write-Host ""
Write-Host "Rollback complete. Run 'docker compose ps' to verify service health."
Write-Host "To undo this rollback: git checkout HEAD -- app/ && docker compose up --build -d"
