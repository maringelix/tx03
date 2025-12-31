@echo off
cd /d c:\Users\tx01\Documents\Projects\tx03

echo Fazendo commit da documentacao...
git add README.md REFERENCE.md
git commit -m "docs: Add Istio Service Mesh documentation to README and REFERENCE"
git push

echo.
echo Concluido!
pause
