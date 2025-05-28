# PowerShell script for Hello World task
param(
    [int]$Count = 10,
    [int]$DelaySeconds = 1
)

Write-Host "=== INICIO DEL SCRIPT HELLO WORLD ===" -ForegroundColor Green
Write-Host "Ejecutando Hello World $Count veces con delay de $DelaySeconds segundos" -ForegroundColor Yellow

# Function to print with timestamp
function Write-TimestampedOutput {
    param([string]$Message, [string]$Color = "White")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp] $Message" -ForegroundColor $Color
}

# Execute Hello World loop
for ($i = 1; $i -le $Count; $i++) {
    Write-TimestampedOutput "Hello World - Iteración $i" "Cyan"
    Start-Sleep -Seconds $DelaySeconds
}

Write-TimestampedOutput "Finalizado Hello World Job" "Green"
Write-Host "=== FIN DEL SCRIPT HELLO WORLD ===" -ForegroundColor Green
