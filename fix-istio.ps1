#!/usr/bin/env pwsh
# Script para corrigir problemas do Istio

Write-Host "🔧 Fazendo commit das correções..." -ForegroundColor Cyan
cd c:\Users\tx01\Documents\Projects\tx03

git add .github/workflows/istio-apply-configs.yml
git commit -m "fix: Remove blocking rollout status check"
git push

Write-Host ""
Write-Host "✅ Commit realizado!" -ForegroundColor Green
Write-Host ""

Write-Host "🚀 Executando workflow (APENAS configs, SEM restart de pods)..." -ForegroundColor Cyan
gh workflow run istio-apply-configs.yml -f restart_pods=false -f apply_configs=true

Write-Host ""
Write-Host "⏳ Aguardando 15s..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host ""
Write-Host "📊 Monitorando workflow..." -ForegroundColor Cyan
for ($i=1; $i -le 20; $i++) {
    $run = (gh run list --workflow="istio-apply-configs.yml" --limit 1 --json status,conclusion | ConvertFrom-Json)[0]
    
    Write-Host "[$i/20] Status: $($run.status)" -NoNewline -ForegroundColor Cyan
    
    if ($run.conclusion) {
        Write-Host " → " -NoNewline
        $color = if ($run.conclusion -eq "success") { "Green" } else { "Red" }
        Write-Host "$($run.conclusion.ToUpper())" -ForegroundColor $color
    } else {
        Write-Host ""
    }
    
    if ($run.status -eq "completed") {
        Write-Host ""
        if ($run.conclusion -eq "success") {
            Write-Host "🎉 WORKFLOW COMPLETADO COM SUCESSO!" -ForegroundColor Green
        } else {
            Write-Host "❌ Workflow falhou" -ForegroundColor Red
        }
        break
    }
    
    Start-Sleep -Seconds 10
}

Write-Host ""
Write-Host "✅ Script finalizado!" -ForegroundColor Green
