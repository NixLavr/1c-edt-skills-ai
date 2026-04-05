[CmdletBinding()]
param(
    [string]$BaseProjectPath,
    [string]$ExtensionProjectPath,
    [string]$OutputFile,
    [string]$BuildRoot,
    [string]$ExtensionName,
    [string]$V8Path,
    [string]$EdtCliPath,
    [string]$JavaBinPath,
    [switch]$KeepTemp
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Resolve-AbsolutePath {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [switch]$AllowMissing
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        if ($AllowMissing) {
            return [System.IO.Path]::GetFullPath($Path)
        }
        return (Resolve-Path $Path).Path
    }

    $combined = Join-Path (Get-Location) $Path
    if ($AllowMissing) {
        return [System.IO.Path]::GetFullPath($combined)
    }
    return (Resolve-Path $combined).Path
}

function Find-LatestFile {
    param(
        [Parameter(Mandatory)]
        [string[]]$Patterns
    )

    foreach ($pattern in $Patterns) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Sort-Object FullName -Descending | Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }

    return $null
}

function Invoke-Step {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    Write-Host "=== $Title ==="
    Write-Host "$FilePath $($Arguments -join ' ')"
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$Title failed with exit code $LASTEXITCODE"
    }
}

function Invoke-DesignerStep {
    param(
        [Parameter(Mandatory)]
        [string]$Title,
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [Parameter(Mandatory)]
        [string]$LogPath,
        [int]$MaxAttempts = 5,
        [int]$RetryDelaySeconds = 3
    )

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if (Test-Path $LogPath) {
            Remove-Item $LogPath -Force -ErrorAction SilentlyContinue
        }

        Invoke-Step -Title "$Title (attempt $attempt/$MaxAttempts)" -FilePath $script:V8Path -Arguments $Arguments

        $logText = ''
        if (Test-Path $LogPath) {
            $logText = Get-Content $LogPath -Raw -ErrorAction SilentlyContinue
        }

        if ($logText -match 'Ошибка блокировки информационной базы для конфигурирования') {
            if ($attempt -eq $MaxAttempts) {
                throw "$Title failed: infobase lock was not released. Log: $LogPath"
            }
            Start-Sleep -Seconds $RetryDelaySeconds
            continue
        }

        if ($logText -match 'Ошибка ') {
            throw "$Title failed. See log: $LogPath"
        }

        Start-Sleep -Seconds 1
        return
    }
}

function Get-ExtensionNameFromXml {
    param(
        [Parameter(Mandatory)]
        [string]$ConfigurationXmlPath
    )

    [xml]$xml = Get-Content $ConfigurationXmlPath
    $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $ns.AddNamespace('d', 'http://v8.1c.ru/8.3/MDClasses')
    $node = $xml.SelectSingleNode('/d:MetaDataObject/d:Configuration/d:Properties/d:Name', $ns)
    if (-not $node -or [string]::IsNullOrWhiteSpace($node.InnerText)) {
        throw "Failed to determine extension name from $ConfigurationXmlPath"
    }
    return $node.InnerText.Trim()
}

if (-not $BaseProjectPath) {
    $BaseProjectPath = Join-Path (Get-Location) 'Информационная_база'
}
if (-not $ExtensionProjectPath) {
    $ExtensionProjectPath = Join-Path (Get-Location) 'Информационная_база.Расширение'
}
if (-not $BuildRoot) {
    $BuildRoot = Join-Path (Get-Location) 'build\cfe-build'
}
if (-not $OutputFile) {
    $OutputFile = Join-Path (Get-Location) 'build\Расширение.cfe'
}

$BaseProjectPath = Resolve-AbsolutePath -Path $BaseProjectPath
$ExtensionProjectPath = Resolve-AbsolutePath -Path $ExtensionProjectPath
$BuildRoot = Resolve-AbsolutePath -Path $BuildRoot -AllowMissing
$OutputFile = Resolve-AbsolutePath -Path $OutputFile -AllowMissing

if (-not $EdtCliPath) {
    $EdtCliPath = Find-LatestFile -Patterns @(
        'C:\Program Files\1C\1CE\components\1c-edt-*\1cedtcli.exe'
    )
}
if (-not $EdtCliPath) {
    throw '1cedtcli.exe not found. Specify -EdtCliPath'
}

if (-not $JavaBinPath) {
    $javaExe = Find-LatestFile -Patterns @(
        'C:\Program Files\1C\1CE\components\axiom-jdk-full-*\bin\java.exe'
    )
    if ($javaExe) {
        $JavaBinPath = Split-Path $javaExe -Parent
    }
}
if (-not $JavaBinPath) {
    throw 'EDT JDK not found. Specify -JavaBinPath'
}

if (-not $V8Path) {
    $V8Path = Find-LatestFile -Patterns @(
        'C:\Program Files\1cv8\*\bin\1cv8.exe',
        'C:\Program Files (x86)\1cv8\*\bin\1cv8.exe'
    )
}
if (-not $V8Path) {
    throw '1cv8.exe not found. Specify -V8Path'
}
$script:V8Path = $V8Path

$edtWorkspace = Join-Path $BuildRoot 'edt-ws'
$edtHome = Join-Path $BuildRoot 'edt-home'
$xmlBase = Join-Path $BuildRoot 'xml-base'
$xmlExt = Join-Path $BuildRoot 'xml-ext'
$ibTemp = Join-Path $BuildRoot 'ib-temp'
$logs = Join-Path $BuildRoot 'logs'

New-Item -ItemType Directory -Force $BuildRoot, $edtWorkspace, $edtHome, $xmlBase, $xmlExt, $ibTemp, $logs | Out-Null

$oldPath = $env:PATH
$env:PATH = "$JavaBinPath;$oldPath"

try {
    Invoke-Step -Title 'Export base project from EDT' -FilePath $EdtCliPath -Arguments @(
        '-data', $edtWorkspace,
        '-timeout', '7200',
        '-command', 'export',
        '--project', $BaseProjectPath,
        '--configuration-files', $xmlBase,
        '-vmargs', "-Duser.home=$edtHome"
    )

    Invoke-Step -Title 'Export extension project from EDT' -FilePath $EdtCliPath -Arguments @(
        '-data', $edtWorkspace,
        '-timeout', '7200',
        '-command', 'export',
        '--project', $ExtensionProjectPath,
        '--configuration-files', $xmlExt,
        '-vmargs', "-Duser.home=$edtHome"
    )

    if (-not $ExtensionName) {
        $ExtensionName = Get-ExtensionNameFromXml -ConfigurationXmlPath (Join-Path $xmlExt 'Configuration.xml')
    }

    $outputDir = Split-Path $OutputFile -Parent
    if ($outputDir) {
        New-Item -ItemType Directory -Force $outputDir | Out-Null
    }

    Invoke-Step -Title 'Create temporary infobase' -FilePath $V8Path -Arguments @(
        'CREATEINFOBASE',
        "File=`"$ibTemp`"",
        '/DisableStartupDialogs'
    )

    Invoke-DesignerStep -Title 'Load base configuration XML' -LogPath (Join-Path $logs 'load-base.log') -Arguments @(
        'DESIGNER',
        '/F', $ibTemp,
        '/LoadConfigFromFiles', $xmlBase,
        '-Format', 'Hierarchical',
        '/Out', (Join-Path $logs 'load-base.log'),
        '/DisableStartupDialogs'
    )

    Invoke-DesignerStep -Title 'Load extension XML' -LogPath (Join-Path $logs 'load-ext.log') -Arguments @(
        'DESIGNER',
        '/F', $ibTemp,
        '/LoadConfigFromFiles', $xmlExt,
        '-Format', 'Hierarchical',
        '-Extension', $ExtensionName,
        '/Out', (Join-Path $logs 'load-ext.log'),
        '/DisableStartupDialogs'
    )

    Invoke-DesignerStep -Title 'Dump CFE' -LogPath (Join-Path $logs 'dump-cfe.log') -Arguments @(
        'DESIGNER',
        '/F', $ibTemp,
        '/DumpCfg', $OutputFile,
        '-Extension', $ExtensionName,
        '/Out', (Join-Path $logs 'dump-cfe.log'),
        '/DisableStartupDialogs'
    )

    if (-not (Test-Path $OutputFile)) {
        throw "Output file was not created: $OutputFile"
    }

    $result = Get-Item $OutputFile
    Write-Host "CFE built successfully: $($result.FullName)"
    Write-Host "Size: $($result.Length) bytes"
    Write-Host "Extension: $ExtensionName"
    Write-Host "Logs: $logs"
}
finally {
    $env:PATH = $oldPath
    if (-not $KeepTemp -and (Test-Path $BuildRoot)) {
        $outputUnderBuildRoot = $OutputFile.StartsWith($BuildRoot, [System.StringComparison]::OrdinalIgnoreCase)
        if (-not $outputUnderBuildRoot) {
            Remove-Item $BuildRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
