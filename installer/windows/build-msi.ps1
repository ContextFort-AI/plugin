# ContextFort Windows MSI Installer Builder
# Creates deployable .msi for Intune/SCCM

param(
    [string]$Version = "1.0.0",
    [switch]$Sign
)

Write-Host "📦 ContextFort Windows Installer Builder" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host ""

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PluginDir = Resolve-Path "$ScriptDir\..\.."
$BuildDir = Join-Path $ScriptDir "build"
$WixObjDir = Join-Path $BuildDir "obj"
$OutputMsi = Join-Path $BuildDir "ContextFort-$Version.msi"

# Check for WiX Toolset
$WixPath = "${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin"
if (-not (Test-Path "$WixPath\candle.exe")) {
    Write-Host "❌ WiX Toolset not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install WiX Toolset v3.11 or later:"
    Write-Host "https://wixtoolset.org/releases/"
    Write-Host ""
    exit 1
}

# Clean build directory
if (Test-Path $BuildDir) {
    Remove-Item -Recurse -Force $BuildDir
}
New-Item -ItemType Directory -Path $BuildDir, $WixObjDir | Out-Null

Write-Host "✅ Build directory created" -ForegroundColor Green
Write-Host ""

# Create WiX source file
Write-Host "📝 Generating WiX source..." -ForegroundColor Yellow

$WixSource = @"
<?xml version="1.0" encoding="UTF-8"?>
<Wix xmlns="http://schemas.microsoft.com/wix/2006/wi">
  <Product Id="*"
           Name="ContextFort"
           Language="1033"
           Version="$Version"
           Manufacturer="ContextFort"
           UpgradeCode="12345678-1234-1234-1234-123456789012">

    <Package InstallerVersion="200"
             Compressed="yes"
             InstallScope="perMachine"
             Description="ContextFort - Browser Agent Monitoring" />

    <MajorUpgrade DowngradeErrorMessage="A newer version is already installed." />
    <MediaTemplate EmbedCab="yes" />

    <Feature Id="ProductFeature" Title="ContextFort" Level="1">
      <ComponentGroupRef Id="ProductComponents" />
      <ComponentRef Id="NativeMessagingHost" />
    </Feature>

    <!-- Install to Program Files -->
    <Directory Id="TARGETDIR" Name="SourceDir">
      <Directory Id="ProgramFilesFolder">
        <Directory Id="INSTALLFOLDER" Name="ContextFort">
          <Directory Id="BinDir" Name="bin" />
          <Directory Id="ExtensionDir" Name="extension" />
          <Directory Id="ConfigDir" Name="config" />
        </Directory>
      </Directory>

      <!-- Native Messaging Host Registry -->
      <Directory Id="ProgramMenuFolder" />
    </Directory>

    <!-- Components -->
    <ComponentGroup Id="ProductComponents" Directory="BinDir">
      <Component Id="NativeProxy" Guid="*">
        <File Id="NativeProxyJs" Source="$($PluginDir)\bin\native-messaging-proxy.js" KeyPath="yes" />
      </Component>
      <Component Id="LaunchScript" Guid="*">
        <File Id="LaunchChromeCmd" Source="$($PluginDir)\bin\launch-chrome.cmd" KeyPath="yes" />
      </Component>
    </ComponentGroup>

    <!-- Native Messaging Host Registry Entry -->
    <Component Id="NativeMessagingHost" Directory="ProgramFilesFolder" Guid="*">
      <RegistryKey Root="HKCU" Key="Software\Google\Chrome\NativeMessagingHosts\com.anthropic.claude_browser_extension">
        <RegistryValue Type="string" Value="[INSTALLFOLDER]config\native-host.json" />
      </RegistryKey>
    </Component>

    <!-- Custom Actions -->
    <CustomAction Id="CreateUserConfig"
                  Directory="INSTALLFOLDER"
                  ExeCommand="cmd /c mkdir &quot;%USERPROFILE%\.contextfort\logs&quot;"
                  Execute="deferred"
                  Return="ignore" />

    <InstallExecuteSequence>
      <Custom Action="CreateUserConfig" After="InstallFiles">NOT Installed</Custom>
    </InstallExecuteSequence>

  </Product>
</Wix>
"@

$WixSourceFile = Join-Path $BuildDir "ContextFort.wxs"
$WixSource | Out-File -FilePath $WixSourceFile -Encoding UTF8

Write-Host "✅ WiX source generated" -ForegroundColor Green
Write-Host ""

# Compile WiX source
Write-Host "🔨 Compiling WiX source..." -ForegroundColor Yellow
& "$WixPath\candle.exe" -out "$WixObjDir\" "$WixSourceFile"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ WiX compilation failed" -ForegroundColor Red
    exit 1
}

Write-Host "✅ WiX compilation complete" -ForegroundColor Green
Write-Host ""

# Link MSI
Write-Host "🔗 Linking MSI..." -ForegroundColor Yellow
& "$WixPath\light.exe" -out "$OutputMsi" -ext WixUIExtension "$WixObjDir\ContextFort.wixobj"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ MSI linking failed" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ MSI built successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Output: $OutputMsi" -ForegroundColor Cyan
Write-Host "Size: $((Get-Item $OutputMsi).Length / 1MB) MB" -ForegroundColor Cyan
Write-Host ""

# Sign if requested
if ($Sign) {
    Write-Host "✍️  Signing MSI..." -ForegroundColor Yellow

    $SignTool = "${env:ProgramFiles(x86)}\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe"

    if (-not (Test-Path $SignTool)) {
        Write-Host "⚠️  signtool.exe not found, skipping signing" -ForegroundColor Yellow
        Write-Host "   Install Windows SDK for signing support" -ForegroundColor Yellow
    } else {
        Write-Host ""
        Write-Host "Sign command:"
        Write-Host "  $SignTool sign /f certificate.pfx /p password /t http://timestamp.digicert.com $OutputMsi"
        Write-Host ""
    }
}

Write-Host "📋 Next Steps:" -ForegroundColor Cyan
Write-Host "==============" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. SIGN THE MSI (Required for Intune):"
Write-Host "   signtool sign /f certificate.pfx /p password \"
Write-Host "     /t http://timestamp.digicert.com \"
Write-Host "     $OutputMsi"
Write-Host ""
Write-Host "2. UPLOAD TO INTUNE:"
Write-Host "   - Open Intune Admin Center"
Write-Host "   - Apps → Windows → Add → Line-of-business app"
Write-Host "   - Upload ContextFort-$Version.msi"
Write-Host "   - Configure app information and assignments"
Write-Host ""
Write-Host "3. TEST INSTALLATION:"
Write-Host "   msiexec /i $OutputMsi /qn"
Write-Host ""
Write-Host "4. SILENT UNINSTALL:"
Write-Host "   msiexec /x {PRODUCT-GUID} /qn"
Write-Host ""
