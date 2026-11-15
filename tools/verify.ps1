# Verificacion del proyecto Dead Shift 3D (compatible con Windows PowerShell 5.1).
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File tools/verify.ps1 quick|full|deps
#   quick: lint, formato, importacion limpia y tests (unitarios y de integracion).
#   full:  quick + bot de recorrido + export web + pesos + busqueda de secretos y
#          peticiones externas + prueba de humo en Chromium (directa, iframe y tactil).
#   deps:  inventario de addons/ y assets/third_party/ contra docs/LICENSES.md,
#          lockfile de Python sincronizado y pip-audit.
# El ejecutable de Godot se toma de la variable GODOT_BIN o del comando godot del PATH.

param(
    [Parameter(Position = 0)]
    [ValidateSet('quick', 'full', 'deps')]
    [string]$Mode = 'quick'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Continue'

$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location -LiteralPath $Root

$Venv = Join-Path $Root 'tools\.venv\Scripts'
$Python = Join-Path $Venv 'python.exe'
$BuildWeb = Join-Path $Root 'build\web'
$ShotsDir = Join-Path $env:TEMP 'deadshift3d-capturas'
$script:Failures = New-Object System.Collections.Generic.List[string]

# Cualquier error inesperado del propio script cuenta como fallo (nunca termina en verde).
trap {
    $script:Failures.Add('error del script: ' + $_)
    Write-Host ('FALLO: error del script: ' + $_) -ForegroundColor Red
    continue
}

# Presupuesto de peso (ARCHITECTURE 5): descarga inicial comprimida y total, en bytes.
$InitialBudget = 25MB
$TotalBudget = 70MB

function Write-Section([string]$Name) {
    Write-Host ''
    Write-Host ('== ' + $Name) -ForegroundColor Cyan
}

function Add-Failure([string]$Message) {
    $script:Failures.Add($Message)
    Write-Host ('FALLO: ' + $Message) -ForegroundColor Red
}

function Remove-Ansi([string]$Text) {
    return ($Text -replace "\x1B\[[0-9;]*[A-Za-z]", '')
}

# Ejecuta un programa y devuelve su codigo de salida y sus lineas (sin colores).
function Invoke-Tool([string]$Exe, [string[]]$Arguments) {
    $lines = & $Exe @Arguments 2>&1 | ForEach-Object { Remove-Ansi ([string]$_) }
    return [pscustomobject]@{ Code = $LASTEXITCODE; Lines = @($lines) }
}

function Show-Lines($Lines, [int]$Max = 60) {
    $Lines | Select-Object -Last $Max | ForEach-Object { Write-Host ('  ' + $_) }
}

function Get-Godot {
    if ($env:GODOT_BIN -and (Test-Path -LiteralPath $env:GODOT_BIN)) {
        return $env:GODOT_BIN
    }
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

# Lineas de Godot que indican error o advertencia del motor o de los scripts.
function Get-EngineProblems($Lines) {
    return @($Lines | Where-Object { $_ -match '(^|\s)(ERROR|WARNING|SCRIPT ERROR):' })
}

function Test-Prerequisites {
    if (-not (Test-Path -LiteralPath $Python)) {
        Add-Failure 'Falta tools/.venv. Crear con: py -3.12 -m venv tools/.venv; tools/.venv/Scripts/python -m pip install -r tools/requirements.txt'
        return $false
    }
    if ($Mode -ne 'deps' -and -not $script:Godot) {
        Add-Failure 'No se encontro Godot: definir GODOT_BIN con la ruta del ejecutable de consola 4.7.2'
        return $false
    }
    return $true
}

function Step-Lint {
    Write-Section 'Lint (gdlint)'
    $r = Invoke-Tool (Join-Path $Venv 'gdlint.exe') @('game', 'tests')
    if ($r.Code -ne 0) { Show-Lines $r.Lines; Add-Failure 'gdlint encontro problemas' }
    else { Write-Host '  sin problemas' }
}

function Step-Format {
    Write-Section 'Formato (gdformat --check)'
    $r = Invoke-Tool (Join-Path $Venv 'gdformat.exe') @('--check', 'game', 'tests')
    if ($r.Code -ne 0) { Show-Lines $r.Lines; Add-Failure 'gdformat: hay archivos sin formato' }
    else { Write-Host '  formato correcto' }
}

function Step-Import {
    Write-Section 'Importacion limpia'
    $r = Invoke-Tool $script:Godot @('--headless', '--path', $Root, '--import')
    $problems = @(Get-EngineProblems $r.Lines)
    if ($r.Code -ne 0 -or $problems.Count -gt 0) {
        Show-Lines $problems
        Add-Failure 'la importacion tuvo errores o advertencias'
    }
    else { Write-Host '  sin errores ni advertencias' }
}

function Step-Tests {
    Write-Section 'Tests (GUT)'
    $r = Invoke-Tool $script:Godot @('--headless', '--path', $Root, '-s', 'addons/gut/gut_cmdln.gd')
    $summary = @($r.Lines | Where-Object { $_ -match '^(Scripts|Tests|Passing Tests|Failing Tests|Risky|Pending|Asserts)\s' })
    Show-Lines $summary 12
    $engine = @(Get-EngineProblems $r.Lines)
    $gutBad = @($r.Lines | Where-Object { $_ -match 'Nothing was run|Ignoring script|\[GUT ERROR\]|\[Failed\]' })
    $passed = @($r.Lines | Where-Object { $_ -match 'All tests passed' }).Count -gt 0
    if ($r.Code -ne 0 -or -not $passed -or $engine.Count -gt 0 -or $gutBad.Count -gt 0) {
        Show-Lines ($engine + $gutBad)
        Add-Failure 'los tests no pasaron limpios'
    }
}

function Step-Bot {
    Write-Section 'Bot de recorrido'
    $runner = Join-Path $Root 'tests\bot\run_bot.gd'
    if (-not (Test-Path -LiteralPath $runner)) {
        Add-Failure 'no existe tests/bot/run_bot.gd'
        return
    }
    # --fixed-fps hace la simulacion determinista y mas rapida que el tiempo real.
    # Escenarios: la partida completa hasta el rescate, el jefe con y sin escopeta, el rescate
    # perdido y la muerte.
    # La partida completa se juega con varias semillas fijas en Facil y con una en Medio
    # (escenario:semilla:dificultad; sin dificultad, Facil).
    $runs = @('full:20261114', 'full:7', 'full:31337', 'full:20261114:medium', 'boss_shotgun:20261114', 'boss_melee:20261114', 'lost:20261114', 'death:20261114')
    foreach ($run in $runs) {
        $parts = $run.Split(':')
        $scenario = $parts[0]
        $seed = $parts[1]
        $difficulty = 'easy'
        if ($parts.Count -gt 2) { $difficulty = $parts[2] }
        Write-Host "  escenario: $scenario (semilla $seed, dificultad $difficulty)"
        $r = Invoke-Tool $script:Godot @('--headless', '--fixed-fps', '60', '--path', $Root, '-s', 'res://tests/bot/run_bot.gd', '--', "--scenario=$scenario", "--seed=$seed", "--difficulty=$difficulty")
        Show-Lines @($r.Lines | Where-Object { $_ -match '^\[bot\] (COMPLETADO|FALLO|inicio)' }) 20
        $engine = @(Get-EngineProblems $r.Lines)
        if ($r.Code -ne 0 -or $engine.Count -gt 0) {
            Show-Lines $engine
            Add-Failure "el bot no completo el escenario $scenario limpio"
        }
    }
}

function Step-Export {
    Write-Section 'Export web (un solo hilo)'
    if (Test-Path -LiteralPath $BuildWeb) {
        Get-ChildItem -LiteralPath $BuildWeb -File | Remove-Item -Force
    }
    else {
        New-Item -ItemType Directory -Path $BuildWeb | Out-Null
    }
    $out = Join-Path $BuildWeb 'index.html'
    $r = Invoke-Tool $script:Godot @('--headless', '--path', $Root, '--export-release', 'Web', $out)
    $problems = @(Get-EngineProblems $r.Lines)
    if ($r.Code -ne 0 -or -not (Test-Path -LiteralPath $out) -or $problems.Count -gt 0) {
        Show-Lines ($problems + $r.Lines) 30
        Add-Failure 'el export web fallo'
        return
    }
    # Archivos propios de la pagina contenedora (sin scripts en linea).
    Copy-Item -LiteralPath (Join-Path $Root 'web\boot.js') -Destination $BuildWeb
    Copy-Item -LiteralPath (Join-Path $Root 'web\boot.css') -Destination $BuildWeb
    Write-Host ('  generado en ' + $BuildWeb)
}

function Get-GzipSize([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $memory = New-Object System.IO.MemoryStream
    $gzip = New-Object System.IO.Compression.GZipStream($memory, [System.IO.Compression.CompressionMode]::Compress)
    $gzip.Write($bytes, 0, $bytes.Length)
    $gzip.Close()
    return $memory.ToArray().Length
}

function Step-Weights {
    Write-Section 'Pesos del export'
    if (-not (Test-Path -LiteralPath $BuildWeb)) { Add-Failure 'no hay build/web'; return }
    $raw = 0
    $compressed = 0
    foreach ($file in Get-ChildItem -LiteralPath $BuildWeb -File) {
        $gz = Get-GzipSize $file.FullName
        $raw += $file.Length
        $compressed += $gz
        Write-Host ('  {0,-34} {1,10:N0} B   gzip {2,10:N0} B' -f $file.Name, $file.Length, $gz)
    }
    Write-Host ('  total sin comprimir: {0:N1} MB; comprimido: {1:N1} MB' -f ($raw / 1MB), ($compressed / 1MB))
    # Hoy todo el juego va en un solo paquete: la descarga inicial es el total comprimido.
    if ($compressed -gt $InitialBudget) { Add-Failure ('descarga inicial comprimida sobre 25 MB') }
    if ($raw -gt $TotalBudget) { Add-Failure ('peso total sobre 70 MB') }
}

function Step-BuildScan {
    Write-Section 'Secretos y peticiones externas en build/web'
    $strict = 'BEGIN (RSA |EC |OPENSSH |)PRIVATE KEY|AKIA[0-9A-Z]{16}|ghp_[A-Za-z0-9]{36}|github_pat_|sk-[A-Za-z0-9]{20,}|xox[baprs]-|AIza[0-9A-Za-z_-]{35}'
    $own = 'api[_-]?key|secret|passw|bearer|token'
    # Solo archivos de texto: en PowerShell 5.1 -Include no filtra con -LiteralPath.
    $textFiles = Get-ChildItem -LiteralPath $BuildWeb -File | Where-Object { @('.html', '.js', '.css', '.json') -contains $_.Extension }
    foreach ($file in $textFiles) {
        $text = [System.IO.File]::ReadAllText($file.FullName)
        if ($text -match $strict) { Add-Failure ('posible secreto en ' + $file.Name) }
    }
    foreach ($name in @('index.html', 'boot.js', 'boot.css')) {
        $path = Join-Path $BuildWeb $name
        if (-not (Test-Path -LiteralPath $path)) { Add-Failure ('falta ' + $name); continue }
        $text = [System.IO.File]::ReadAllText($path)
        if ($text -match 'https?://') { Add-Failure ('direccion externa en ' + $name) }
        if ($text -match $own) { Add-Failure ('palabra sensible en ' + $name) }
    }
    $html = [System.IO.File]::ReadAllText((Join-Path $BuildWeb 'index.html'))
    if ($html -match '<script>|<script(?![^>]*\ssrc=)[^>]*>') { Add-Failure 'index.html contiene scripts en linea' }
    if ($html -match '\son[a-z]+\s*=') { Add-Failure 'index.html contiene manejadores de eventos en linea' }
    Write-Host ('  revisados ' + @($textFiles).Count + ' archivos de texto')
}

function Step-Smoke {
    Write-Section 'Prueba de humo en Chromium'
    $smoke = Join-Path $Root 'tools\web_smoke.py'
    $desk = Invoke-Tool $Python @('-I', $smoke, $BuildWeb, $ShotsDir)
    Show-Lines $desk.Lines 20
    if ($desk.Code -ne 0) { Add-Failure 'prueba de humo (PC) con problemas' }
    $touch = Invoke-Tool $Python @('-I', $smoke, $BuildWeb, $ShotsDir, '--touch')
    Show-Lines $touch.Lines 20
    if ($touch.Code -ne 0) { Add-Failure 'prueba de humo (tactil) con problemas' }
    Write-Host ('  capturas en ' + $ShotsDir)
}

function Step-Licenses {
    Write-Section 'Inventario de terceros contra docs/LICENSES.md'
    $licensesPath = Join-Path $Root 'docs\LICENSES.md'
    if (-not (Test-Path -LiteralPath $licensesPath)) { Add-Failure 'falta docs/LICENSES.md'; return }
    $licenses = [System.IO.File]::ReadAllText($licensesPath)
    $dirs = @()
    if (Test-Path -LiteralPath (Join-Path $Root 'addons')) {
        $dirs += Get-ChildItem -LiteralPath (Join-Path $Root 'addons') -Directory
    }
    $third = Join-Path $Root 'assets\third_party'
    if (Test-Path -LiteralPath $third) {
        foreach ($pack in Get-ChildItem -LiteralPath $third -Directory) {
            $dirs += $pack
            if (-not (Get-ChildItem -LiteralPath $pack.FullName -File -Filter 'LICENSE*')) {
                Add-Failure ('el pack ' + $pack.Name + ' no tiene archivo de licencia')
            }
        }
    }
    foreach ($dir in $dirs) {
        if ($licenses -notmatch [regex]::Escape($dir.Name)) { Add-Failure ($dir.Name + ' no figura en docs/LICENSES.md') }
        else { Write-Host ('  ' + $dir.Name + ': anotado') }
    }
}

function Step-PythonLock {
    Write-Section 'Lockfile de Python'
    $r = Invoke-Tool $Python @('-m', 'pip', 'freeze')
    $installed = @($r.Lines | Where-Object { $_ -match '==' } | Sort-Object)
    $locked = @(Get-Content -LiteralPath (Join-Path $Root 'tools\requirements.txt') | Where-Object { $_ -match '==' } | Sort-Object)
    $diff = Compare-Object $installed $locked
    if ($diff) { $diff | ForEach-Object { Write-Host ('  ' + $_.InputObject + ' ' + $_.SideIndicator) }; Add-Failure 'tools/.venv no coincide con tools/requirements.txt' }
    else { Write-Host '  sincronizado' }
    foreach ($line in $locked) {
        if ($line -notmatch '^[A-Za-z0-9_.\-]+==[0-9][A-Za-z0-9_.\-]*$') { Add-Failure ('version no exacta: ' + $line) }
    }
}

function Step-PipAudit {
    Write-Section 'pip-audit'
    $r = Invoke-Tool $Python @('-m', 'pip_audit', '--progress-spinner', 'off', '-r', (Join-Path $Root 'tools\requirements.txt'), '--no-deps', '--disable-pip')
    Show-Lines $r.Lines 30
    if ($r.Code -ne 0) { Add-Failure 'pip-audit encontro vulnerabilidades o no pudo ejecutarse' }
}

$script:Godot = Get-Godot
if (Test-Prerequisites) {
    switch ($Mode) {
        'quick' {
            Step-Lint; Step-Format; Step-Import; Step-Tests
        }
        'full' {
            Step-Lint; Step-Format; Step-Import; Step-Tests
            Step-Bot; Step-Export
            if ($script:Failures.Count -eq 0) { Step-Weights; Step-BuildScan; Step-Smoke }
        }
        'deps' {
            Step-Licenses; Step-PythonLock; Step-PipAudit
        }
    }
}

Write-Host ''
if ($script:Failures.Count -gt 0) {
    Write-Host ('verify ' + $Mode + ': ' + $script:Failures.Count + ' fallo(s)') -ForegroundColor Red
    exit 1
}
Write-Host ('verify ' + $Mode + ': todo correcto') -ForegroundColor Green
exit 0
