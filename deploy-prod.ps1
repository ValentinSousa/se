# How to install in Windows:
# 1. Open PowerShell and run: notepad $PROFILE
# 2. Paste this entire code block, save, and close Notepad.
# 3. Reload your profile by running: . $PROFILE
#
# Usage: 
# deploy-prod                     -> Uses last commit message
# deploy-prod "Feature complete"  -> Uses custom commit message

function deploy-prod {
    param (
        [string]$CommitMessage
    )

    $localBranch = (git branch --show-current).Trim()
    
    if ($localBranch -eq "qa" -or $localBranch -eq "prod") {
        Write-Error "❌ You are on $localBranch branch. Switch to a feature branch!"
        return
    }

    # If no message provided, fetch the last local commit message
    if ([string]::IsNullOrEmpty($CommitMessage)) {
        $CommitMessage = (git log -1 --format=%s).Trim()
    }

    # 1. AWS login
    Write-Host "`n🔐 Step 1: AWS Login..." -ForegroundColor Cyan
    aws login
    Write-Host "👍 AWS Auth success." -ForegroundColor Green

    # 2. Pull remote prod into local feature branch
    Write-Host "`n📥 Step 2: Pulling remote prod into $localBranch..." -ForegroundColor Cyan
    git pull origin prod
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "💥 CONFLICT WITH PROD!"
        Write-Warning "⚠️ Fix conflicts manually in $localBranch, commit, and re-run."
        return
    }

    # 3. Switch to local prod branch
    Write-Host "`n🔄 Step 3: Switching to local prod..." -ForegroundColor Cyan
    git checkout prod

    # 4. Merge feature branch into local prod (Squash to single commit)
    Write-Host "`n🔀 Step 4: Squashing $localBranch into local prod..." -ForegroundColor Cyan
    git merge --squash $localBranch
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "💥 Unexpected conflict during merge!"
        git merge --abort 2>$null
        git checkout $localBranch
        return
    }

    # Commit with the selected message
    git commit -m "$CommitMessage"

    # 5. Push local prod to remote prod
    Write-Host "`n🚀 Step 5: Pushing local prod to remote prod..." -ForegroundColor Cyan
    git push origin prod
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "💥 Push failed!"
        git checkout $localBranch
        return
    }

    # 6. Back to feature branch
    Write-Host "`n🔙 Step 6: Returning to $localBranch..." -ForegroundColor Cyan
    git checkout $localBranch

    Write-Host "`n✅ Done. Production updated with message: '$CommitMessage'" -ForegroundColor Green
}