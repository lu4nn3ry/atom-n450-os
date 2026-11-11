# remote_control.ps1 - Remote CLI and Diagnostic Tool for Itautec W7020
param(
    [string]$TargetIP = "",
    [string]$Command = "lscpu; ip a; lspci"
)

$envFile = Join-Path $PSScriptRoot "..\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | Where-Object { $_ -match '^([^#=]+)=(.*)$' } | ForEach-Object {
        $key = $matches[1].Trim()
        $val = $matches[2].Trim().Trim('"').Trim("'")
        [System.Environment]::SetEnvironmentVariable($key, $val, "Process")
    }
}

$rootPass = if ($env:ROOT_PASS) { $env:ROOT_PASS } else { "atom" }

# 1. Discover Itautec W7020 if IP is not provided
if (-not $TargetIP) {
    Write-Host "[DISCOVER] Procurando Itautec W7020 na sub-rede 192.168.0.0/24..." -ForegroundColor Cyan
    $activeHosts = @()
    1..254 | ForEach-Object -Parallel {
        $ip = "192.168.0.$_"
        if (Test-Connection -ComputerName $ip -Count 1 -Quiet -TimeoutSeconds 1) {
            $ip
        }
    } -ThrottleLimit 50 | ForEach-Object {
        $activeHosts += $_
    }

    Write-Host "[DISCOVER] IPs respondendo na rede:" -ForegroundColor Green
    foreach ($hostIp in $activeHosts) {
        Write-Host "  -> $hostIp"
    }

    # Check for port 22 (SSH)
    foreach ($hostIp in $activeHosts) {
        if ($hostIp -eq "192.168.0.16" -or $hostIp -eq "192.168.0.1") { continue }
        $tcp = New-Object System.Net.Sockets.TcpClient
        try {
            $ar = $tcp.BeginConnect($hostIp, 22, $null, $null)
            $success = $ar.AsyncWaitHandle.WaitOne(800, $false)
            if ($success -and $tcp.Connected) {
                Write-Host "  [+] Porta 22 (SSH) ABERTA em $hostIp! Identificado potencial Itautec W7020!" -ForegroundColor Yellow
                $TargetIP = $hostIp
                break
            }
        } catch {} finally {
            $tcp.Close()
        }
    }
}

if (-not $TargetIP) {
    Write-Host "[ERRO] Não foi possível encontrar automaticamente o IP do Itautec W7020. Especifique com -TargetIP <IP>." -ForegroundColor Red
    exit 1
}

Write-Host "`n[CONNECT] Conectando a root@$TargetIP (Senha padrao: $rootPass)..." -ForegroundColor Cyan
Write-Host "[EXEC] Comando: $Command`n" -ForegroundColor DarkGray

# Execute via SSH
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null "root@$TargetIP" $Command
