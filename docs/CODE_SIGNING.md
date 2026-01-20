# Code Signing Guide

ContextFort components require code signing for enterprise deployment.

## Why Code Signing?

✅ **Prevents tampering** - Verifies binaries haven't been modified
✅ **Establishes trust** - Users/IT can verify publisher identity
✅ **Passes Gatekeeper** - Required for macOS 10.15+ without warnings
✅ **Required for MDM** - Jamf/Intune reject unsigned packages
✅ **SmartScreen bypass** - Windows won't show "Unknown publisher" warning

## Components to Sign

### macOS
1. **Native Messaging Proxy** (`native-messaging-proxy.js` - if compiled to binary)
2. **.pkg Installer** - Required for Jamf deployment
3. **Chrome Extension** - Optional but recommended

### Windows
1. **Native Messaging Proxy** (.exe if compiled)
2. **.msi Installer** - Required for Intune deployment
3. **PowerShell Scripts** - Optional

## macOS Code Signing

### Prerequisites

1. **Apple Developer Account** ($99/year)
   - Individual or Organization account
   - Enroll at: https://developer.apple.com

2. **Developer ID Certificate**
   - Type: "Developer ID Application" (for binaries)
   - Type: "Developer ID Installer" (for .pkg files)
   - Request via Xcode or developer.apple.com

3. **Install Certificate**
   ```bash
   # Check installed certificates
   security find-identity -v -p codesigning
   ```

### Sign Binaries

```bash
# Sign native messaging proxy (if compiled)
codesign --sign "Developer ID Application: Your Name (TEAM_ID)" \
         --timestamp \
         --options runtime \
         /usr/local/contextfort/bin/native-messaging-proxy

# Verify signature
codesign --verify --verbose /usr/local/contextfort/bin/native-messaging-proxy

# Check entitlements
codesign --display --entitlements - /usr/local/contextfort/bin/native-messaging-proxy
```

### Sign .pkg Installer

```bash
# Build unsigned package first
./installer/macos/build-pkg.sh

# Sign the package
productsign --sign "Developer ID Installer: Your Name (TEAM_ID)" \
             installer/macos/build/ContextFort-1.0.0.pkg \
             installer/macos/build/ContextFort-1.0.0-signed.pkg

# Verify
pkgutil --check-signature installer/macos/build/ContextFort-1.0.0-signed.pkg
```

### Notarization (macOS 10.15+)

**Required** for distribution outside Mac App Store.

#### 1. Create App-Specific Password
1. Go to: https://appleid.apple.com
2. Sign in → Security → App-Specific Passwords
3. Generate password, save to Keychain:
   ```bash
   xcrun notarytool store-credentials "AC_PASSWORD" \
     --apple-id "your@email.com" \
     --team-id "TEAM_ID"
   ```

#### 2. Submit for Notarization
```bash
# Submit package
xcrun notarytool submit \
  installer/macos/build/ContextFort-1.0.0-signed.pkg \
  --keychain-profile "AC_PASSWORD" \
  --wait

# Check status
xcrun notarytool log <submission-id> --keychain-profile "AC_PASSWORD"
```

#### 3. Staple Notarization Ticket
```bash
# Attach notarization ticket to package
xcrun stapler staple installer/macos/build/ContextFort-1.0.0-signed.pkg

# Verify
xcrun stapler validate installer/macos/build/ContextFort-1.0.0-signed.pkg
```

### Hardened Runtime & Entitlements

For binaries (if compiled from Node.js):

**entitlements.plist:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
```

Sign with entitlements:
```bash
codesign --sign "Developer ID Application: Your Name" \
         --entitlements entitlements.plist \
         --options runtime \
         --timestamp \
         native-messaging-proxy
```

## Windows Code Signing

### Prerequisites

1. **Code Signing Certificate**
   - From: DigiCert, Sectigo, GlobalSign, etc.
   - Type: "Code Signing Certificate" or "EV Code Signing"
   - Cost: ~$100-500/year

2. **Windows SDK** (for signtool.exe)
   - Download: https://developer.microsoft.com/en-us/windows/downloads/windows-sdk/
   - Includes signtool.exe

3. **Certificate Formats**
   - `.pfx` or `.p12` file (certificate + private key)
   - Or: Hardware token (USB key for EV certificates)

### Sign .msi Installer

```powershell
# Sign with timestamp
signtool sign `
  /f certificate.pfx `
  /p <password> `
  /t http://timestamp.digicert.com `
  /fd SHA256 `
  /d "ContextFort" `
  /du "https://contextfort.com" `
  installer\windows\build\ContextFort-1.0.0.msi

# Verify signature
signtool verify /pa installer\windows\build\ContextFort-1.0.0.msi
```

### Sign Binaries (.exe)

```powershell
# Sign native-messaging-proxy.exe (if compiled)
signtool sign `
  /f certificate.pfx `
  /p <password> `
  /t http://timestamp.digicert.com `
  /fd SHA256 `
  bin\native-messaging-proxy.exe

# Verify
signtool verify /pa bin\native-messaging-proxy.exe
```

### EV Certificate (Recommended)

**Benefits:**
- Immediate SmartScreen reputation
- No "Unknown Publisher" warnings
- Required for kernel-mode drivers

**Process:**
- Hardware USB token required
- Must be inserted during signing
- No password in command (token PIN prompt)

```powershell
# Sign with EV certificate on token
signtool sign `
  /n "Your Company Name" `
  /t http://timestamp.digicert.com `
  /fd SHA256 `
  installer\windows\build\ContextFort-1.0.0.msi
```

## Chrome Extension Signing

Chrome extensions are auto-signed by Chrome Web Store. For private/enterprise extensions:

### Method 1: Chrome Web Store (Recommended)
1. Upload to Chrome Web Store
2. Set visibility to "Unlisted" or "Private"
3. Chrome auto-signs extension

### Method 2: Private CRX

```bash
# Generate private key (first time only)
openssl genrsa 2048 | openssl pkcs8 -topk8 -nocrypt -out key.pem

# Pack extension with Chrome
/Applications/Google\ Chrome.app/Contents/MacOS/Google\ Chrome \
  --pack-extension=extension \
  --pack-extension-key=key.pem

# Outputs: extension.crx (signed)
```

**Note:** Chrome 137+ removed `--load-extension` for branded Chrome. Use Chrome for Testing or ExtensionInstallForcelist policy.

## Automated Signing in CI/CD

### GitHub Actions (macOS)

```yaml
name: Sign macOS Package

on: [push]

jobs:
  sign:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Import Certificate
        env:
          CERTIFICATE_BASE64: ${{ secrets.MACOS_CERTIFICATE }}
          P12_PASSWORD: ${{ secrets.MACOS_CERT_PASSWORD }}
          KEYCHAIN_PASSWORD: ${{ secrets.KEYCHAIN_PASSWORD }}
        run: |
          # Create keychain
          security create-keychain -p "$KEYCHAIN_PASSWORD" build.keychain
          security default-keychain -s build.keychain
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" build.keychain

          # Import certificate
          echo $CERTIFICATE_BASE64 | base64 --decode > certificate.p12
          security import certificate.p12 -k build.keychain -P "$P12_PASSWORD" -T /usr/bin/codesign

      - name: Build and Sign
        run: |
          ./installer/macos/build-pkg.sh
          productsign --sign "Developer ID Installer" \
            installer/macos/build/ContextFort-1.0.0.pkg \
            installer/macos/build/ContextFort-1.0.0-signed.pkg

      - name: Notarize
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_PASSWORD: ${{ secrets.APPLE_APP_PASSWORD }}
          TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          xcrun notarytool submit \
            installer/macos/build/ContextFort-1.0.0-signed.pkg \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_PASSWORD" \
            --team-id "$TEAM_ID" \
            --wait

          xcrun stapler staple installer/macos/build/ContextFort-1.0.0-signed.pkg
```

### GitHub Actions (Windows)

```yaml
name: Sign Windows Installer

on: [push]

jobs:
  sign:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build MSI
        run: |
          powershell -File installer\windows\build-msi.ps1

      - name: Sign MSI
        env:
          CERTIFICATE_BASE64: ${{ secrets.WINDOWS_CERTIFICATE }}
          CERT_PASSWORD: ${{ secrets.WINDOWS_CERT_PASSWORD }}
        run: |
          # Decode certificate
          [System.Convert]::FromBase64String($env:CERTIFICATE_BASE64) | Set-Content -Path certificate.pfx -Encoding Byte

          # Sign
          & "C:\Program Files (x86)\Windows Kits\10\bin\10.0.22621.0\x64\signtool.exe" sign `
            /f certificate.pfx `
            /p $env:CERT_PASSWORD `
            /t http://timestamp.digicert.com `
            /fd SHA256 `
            installer\windows\build\ContextFort-1.0.0.msi
```

## Troubleshooting

### macOS: "Developer cannot be verified"
- Notarization required for macOS 10.15+
- Run: `spctl --assess --verbose /path/to/app`
- Temporary bypass: `xattr -cr /path/to/app` (NOT for distribution)

### Windows: "Unknown Publisher" warning
- Certificate not trusted by Windows
- SmartScreen reputation takes time (weeks-months)
- Use EV certificate for immediate trust

### Chrome: Extension not loading
- Check manifest.json has "key" field for consistent ID
- Verify ExtensionInstallForcelist policy applied
- Chrome 137+ requires Chrome for Testing for --load-extension

## Cost Summary

| Item | Cost | Frequency |
|------|------|-----------|
| Apple Developer Program | $99 | Annual |
| Windows Code Signing Cert | $100-200 | Annual |
| Windows EV Code Signing | $300-500 | Annual |
| **Total (Standard)** | **~$200-300** | **Annual** |
| **Total (EV)** | **~$400-600** | **Annual** |

## Security Best Practices

✅ **Store private keys securely** - Use hardware tokens for EV certs
✅ **Rotate certificates** - Before expiration
✅ **Timestamp signatures** - Remains valid after cert expires
✅ **Audit signing operations** - Log all sign events
✅ **Restrict access** - Only CI/CD and release managers
✅ **Use secrets management** - GitHub Secrets, Azure Key Vault, AWS Secrets Manager

## References

- [Apple Code Signing Guide](https://developer.apple.com/support/code-signing/)
- [Microsoft Authenticode](https://docs.microsoft.com/en-us/windows-hardware/drivers/install/authenticode)
- [Chrome Extension Signing](https://developer.chrome.com/docs/extensions/mv3/linux_hosting/)
