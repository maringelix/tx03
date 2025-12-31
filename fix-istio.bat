@echo off
cd /d c:\Users\tx01\Documents\Projects\tx03

echo Fazendo commit...
git add .github/workflows/istio-apply-configs.yml
git commit -m "fix: Remove blocking rollout status check"
git push

echo.
echo Executando workflow...
set GH_PROMPT_DISABLED=1
gh workflow run istio-apply-configs.yml -f restart_pods=false -f apply_configs=true

echo.
echo Aguardando 20 segundos...
timeout /t 20 /nobreak

echo.
echo Verificando status...
gh run list --workflow="istio-apply-configs.yml" --limit 3

echo.
echo Concluido!
pause
