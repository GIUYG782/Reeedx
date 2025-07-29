$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#region Variables
$LemonWareFolderPath = "$env:LOCALAPPDATA\LemonWare"
$LemonWareOldFolderPath = "$HOME\LemonWare-cli"
#endregion Variables

#region Functions
function Write-Success {
  [CmdletBinding()]
  param ()
  process {
    Write-Host -Object ' > OK' -ForegroundColor 'Green'
  }
}

function Write-Unsuccess {
  [CmdletBinding()]
  param ()
  process {
    Write-Host -Object ' > ERROR' -ForegroundColor 'Red'
  }
}

function Test-Admin {
  [CmdletBinding()]
  param ()
  begin {
    Write-Host -Object "Checking if the script is not being run as administrator..." -NoNewline
  }
  process {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    -not $currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  }
}

function Test-PowerShellVersion {
  [CmdletBinding()]
  param ()
  begin {
    $PSMinVersion = [version]'5.1'
  }
  process {
    Write-Host -Object 'Checking if your PowerShell version is compatible...' -NoNewline
    $PSVersionTable.PSVersion -ge $PSMinVersion
  }
}

function Move-OldLemonWareFolder {
  [CmdletBinding()]
  param ()
  process {
    if (Test-Path -Path $LemonWareOldFolderPath) {
      Write-Host -Object 'Moving the old LemonWare folder...' -NoNewline
      Copy-Item -Path "$LemonWareOldFolderPath\*" -Destination $LemonWareFolderPath -Recurse -Force
      Remove-Item -Path $LemonWareOldFolderPath -Recurse -Force
      Write-Success
    }
  }
}

function Get-LemonWare {
  [CmdletBinding()]
  param ()
  begin {
    if ($env:PROCESSOR_ARCHITECTURE -eq 'AMD64') {
      $architecture = 'x64'
    }
    elseif ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') {
      $architecture = 'arm64'
    }
    else {
      $architecture = 'x32'
    }
    if ($v) {
      if ($v -match '^\d+\.\d+\.\d+$') {
        $targetVersion = $v
      }
      else {
        Write-Warning -Message "You have specified an invalid LemonWare version: $v `nThe version must be in the following format: 1.2.3"
        Pause
        exit
      }
    }
    else {
      Write-Host -Object 'Fetching the latest LemonWare version...' -NoNewline
      $latestRelease = Invoke-RestMethod -Uri 'https://api.github.com/repos/LemonWare/cli/releases/latest'
      $targetVersion = $latestRelease.tag_name -replace 'v', ''
      Write-Success
    }
    $archivePath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), "LemonWare.zip")
  }
  process {
    Write-Host -Object "Downloading LemonWare v$targetVersion..." -NoNewline
    $Parameters = @{
      Uri            = "https://github.com/LemonWare/cli/releases/download/v$targetVersion/LemonWare-$targetVersion-windows-$architecture.zip"
      UseBasicParsin = $true
      OutFile        = $archivePath
    }
    Invoke-WebRequest @Parameters
    Write-Success
  }
  end {
    $archivePath
  }
}

function Add-LemonWaretifyToPath {
  [CmdletBinding()]
  param ()
  begin {
    Write-Host -Object 'Making LemonWare available in the PATH...' -NoNewline
    $user = [EnvironmentVariableTarget]::User
    $path = [Environment]::GetEnvironmentVariable('PATH', $user)
  }
  process {
    $path = $path -replace "$([regex]::Escape($LemonWareOldFolderPath))\\*;*", ''
    if ($path -notlike "*$LemonWaretifyFolderPath*") {
      $path = "$path;$LemonWaretifyFolderPath"
    }
  }
  end {
    [Environment]::SetEnvironmentVariable('PATH', $path, $user)
    $env:PATH = $path
    Write-Success
  }
}

function Install-LemonWare {
  [CmdletBinding()]
  param ()
  begin {
    Write-Host -Object 'Installing LemonWare...'
  }
  process {
    $archivePath = Get-LemonWare
    Write-Host -Object 'Extracting LemonWare...' -NoNewline
    Expand-Archive -Path $archivePath -DestinationPath $LemonWaretifyFolderPath -Force
    Write-Success
    Add-LemonWaretifyToPath
  }
  end {
    Remove-Item -Path $archivePath -Force -ErrorAction 'SilentlyContinue'
    Write-Host -Object 'LemonWare Unlocker was successfully installed!' -ForegroundColor 'Green'
  }
}
#endregion Functions

#region Main
#region Checks
if (-not (Test-PowerShellVersion)) {
  Write-Unsuccess
  Write-Warning -Message 'PowerShell 5.1 or higher is required to run this script'
  Write-Warning -Message "You are running PowerShell $($PSVersionTable.PSVersion)"
  Write-Host -Object 'PowerShell 5.1 install guide:'
  Write-Host -Object 'https://learn.microsoft.com/skypeforbusiness/set-up-your-computer-for-windows-powershell/download-and-install-windows-powershell-5-1'
  Write-Host -Object 'PowerShell 7 install guide:'
  Write-Host -Object 'https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows'
  Pause
  exit
}
else {
  Write-Success
}
if (-not (Test-Admin)) {
  Write-Unsuccess
  Write-Warning -Message "The script was run as administrator. This can result in problems with the installation process or unexpected behavior. Do not continue if you do not know what you are doing."
  $Host.UI.RawUI.Flushinputbuffer()
  $choices = [System.Management.Automation.Host.ChoiceDescription[]] @(
    (New-Object System.Management.Automation.Host.ChoiceDescription '&Yes', 'Abort installation.'),
    (New-Object System.Management.Automation.Host.ChoiceDescription '&No', 'Resume installation.')
  )
  $choice = $Host.UI.PromptForChoice('', 'Do you want to abort the installation process?', $choices, 0)
  if ($choice -eq 0) {
    Write-Host -Object 'LemonWare installation aborted' -ForegroundColor 'Yellow'
    Pause
    exit
  }
}
else {
  Write-Success
}
#endregion Checks

#regionLemonWare
Move-OldLemonWareFolder
Install-LemonWare
Write-Host -Object "`nRun" -NoNewline
Write-Host -Object ' LemonWare -h ' -NoNewline -ForegroundColor 'Cyan'
Write-Host -Object 'to get started'
#endregion LemonWare Unlocker

#region Marketplace
$Host.UI.RawUI.Flushinputbuffer()
$choices = [System.Management.Automation.Host.ChoiceDescription[]] @(
    (New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "LemonWare Unlocker."),
    (New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Do not install LemonWare Unlocker.")
)
$choice = $Host.UI.PromptForChoice('', "`nDo you also want to install LemonWare Unlocker? It will become available within the Spotify client, where you can easily install themes and extensions.", $choices, 0)
if ($choice -eq 1) {
  Write-Host -Object 'LemonWare Unlocker installation aborted' -ForegroundColor 'Yellow'
}
else {
  Write-Host -Object 'Starting the LemonWare installation script..'
  $Parameters = @{
    Uri             = 'https://raw.githubusercontent.com/spicetify/spicetify-marketplace/main/resources/install.ps1'
    UseBasicParsing = $true
  }
  Invoke-WebRequest @Parameters | Invoke-Expression
}
#endregion Marketplace
#endregion Main