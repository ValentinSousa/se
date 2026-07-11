# How to install in Windows:
# 1. Open PowerShell and run: notepad $PROFILE
# 2. Paste this entire code block, save, and close Notepad.
# 3. Reload your profile by running: . $PROFILE
#
# Usage: deploy-qa

function deploy-qa {
    $localBranch = (git branch --show-current).Trim()
    
    if ($localBranch -eq "qa" -or $localBranch -eq "prod") {
        Write-Error "❌ You are on $localBranch branch. Switch to a feature branch!"
        return
    }

    # 1. AWS login
    Write-Host "`n🔐 Step 1: AWS Login..." -ForegroundColor Cyan
    aws login
    Write-Host "👍 AWS Auth success." -ForegroundColor Green

    # 2. Pull prod
    Write-Host "`n📥 Step 2: Fetching prod..." -ForegroundColor Cyan
    git fetch origin prod
    
    # 3. Merge prod
    Write-Host "`n🔀 Step 3: Merging prod into $localBranch..." -ForegroundColor Cyan
    git merge origin/prod -m "Merge remote prod into $localBranch"
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "💥 CONFLICT WITH PROD!"
        Write-Warning "⚠️ Script stopped. Fix conflicts manually, commit, and re-run."
        return
    }

    # Generate patch
    $patchFile = Join-Path $env:TEMP "patch_$localBranch.patch"
    git diff origin/prod HEAD > $patchFile

    if ((Get-Item $patchFile).Length -eq 0) {
        Write-Host "🤷‍♂️ No changes detected against prod." -ForegroundColor Yellow
        Remove-Item $patchFile -Force
        return
    }

    # 4. Update qa
    Write-Host "`n🔄 Step 4: Updating QA branch..." -ForegroundColor Cyan
    git checkout qa
    git pull origin qa

    # 5. Apply changes to QA
    Write-Host "`n✍️ Step 5: Applying changes to QA files..." -ForegroundColor Cyan
    git apply --3way $patchFile
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "💥 CONFLICT IN QA BRANCH!"
        Write-Warning "⚠️ Someone modified the same files in QA. Script stopped on 'qa' branch."
        Write-Warning "Fix conflicts, commit/push manually, then checkout back to $localBranch."
        Remove-Item $patchFile -Force
        return
    }
    Remove-Item $patchFile -Force

    # 6. Commit and push qa
    Write-Host "`n🚀 Step 6: Pushing to QA..." -ForegroundColor Cyan
    git add .
    git diff --staged --quiet
    if ($LASTEXITCODE -ne 0) {
        git commit -m "Sync updates from $localBranch"
        git push origin qa
    } else {
        Write-Host "ℹ️ QA is already up to date." -ForegroundColor Yellow
    }

    # 7. Back to local
    Write-Host "`n🔙 Step 7: Returning to $localBranch..." -ForegroundColor Cyan
    git checkout $localBranch

    Write-Host "`n✅ Done. Go run tests!" -ForegroundColor Green
}