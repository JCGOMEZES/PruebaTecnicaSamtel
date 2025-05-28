# PowerShell script for file creation task
param(
    [int]$FileCount = 10,
    [string]$OutputDirectory = "temp-files"
)

Write-Host "=== INICIO DEL SCRIPT CREATE FILES ===" -ForegroundColor Green
Write-Host "Creando $FileCount archivos en directorio: $OutputDirectory" -ForegroundColor Yellow

# Function to print with timestamp
function Write-TimestampedOutput {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

# Create output directory
if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    Write-TimestampedOutput "Directorio creado: $OutputDirectory" "Green"
}

Set-Location $OutputDirectory

# Create files with date information
for ($i = 1; $i -le $FileCount; $i++) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "file_${i}_${timestamp}.txt"
    $content = @"
Archivo creado el: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Número de archivo: $i
Nombre del archivo: $filename
Generado por: Azure DevOps Pipeline
Entorno: $env:ENVIRONMENT
Build ID: $env:BUILD_BUILDID
"@
    
    $content | Out-File -FilePath $filename -Encoding UTF8
    Write-TimestampedOutput "Creado archivo: $filename" "Cyan"
    Start-Sleep -Seconds 1
}

Write-Host ""
Write-TimestampedOutput "=== LISTADO DE ARCHIVOS CREADOS ===" "Yellow"
Get-ChildItem -Name "*.txt" | ForEach-Object {
    Write-TimestampedOutput "Archivo: $_" "White"
}

Write-Host ""
Write-TimestampedOutput "=== CONTENIDO DE LOS ARCHIVOS ===" "Yellow"
Get-ChildItem "*.txt" | ForEach-Object {
    Write-Host "--- Contenido de $($_.Name) ---" -ForegroundColor Magenta
    Get-Content $_.FullName
    Write-Host ""
}

Write-TimestampedOutput "Finalizado Create Files Job" "Green"
Write-Host "=== FIN DEL SCRIPT CREATE FILES ===" -ForegroundColor Green