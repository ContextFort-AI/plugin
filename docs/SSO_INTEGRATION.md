# SSO Integration Guide

ContextFort supports Single Sign-On (SSO) integration with enterprise identity providers instead of storing tokens locally.

## Supported Identity Providers

✅ **Okta**
✅ **Azure AD / Microsoft Entra ID**
✅ **Google Workspace**
✅ **OneLogin**
✅ **Auth0**
✅ **Generic SAML 2.0**
✅ **Generic OAuth 2.0 / OpenID Connect**

## Architecture Overview

```
┌─────────────────┐
│  Claude Desktop │
│   / Code CLI    │
└────────┬────────┘
         │
         ▼
┌──────────────────────────────┐
│  Native Messaging Proxy      │
│  (ContextFort)               │
└──────────┬───────────────────┘
           │
           ▼
   ┌───────────────┐
   │  SSO Module   │
   │               │
   │  1. Check for │
   │     existing  │
   │     token     │
   │               │
   │  2. If none,  │
   │     launch    │
   │     browser   │
   │     for SSO   │
   │               │
   │  3. Exchange  │
   │     for token │
   │               │
   │  4. Store in  │
   │     secure    │
   │     storage   │
   └───────┬───────┘
           │
           ▼
   ┌────────────────────┐
   │  Identity Provider │
   │  (Okta/Azure AD)   │
   └────────────────────┘
```

## Implementation Options

### Option 1: Browser-Based Flow (Recommended)

**How it works:**
1. User triggers Claude Desktop/Code
2. ContextFort detects no auth token
3. Launches browser to IdP login page
4. User authenticates via SSO
5. IdP redirects to localhost callback
6. ContextFort captures token
7. Stores token in encrypted file
8. Token used for future sessions

**Benefits:**
- Standard OAuth flow
- No password storage
- MFA support
- Audit trail in IdP

### Option 2: Device Code Flow

**How it works:**
1. ContextFort requests device code from IdP
2. Shows code to user
3. User visits URL and enters code
4. User authenticates via SSO
5. ContextFort polls IdP for token
6. Token stored securely

**Benefits:**
- Works on headless systems
- No localhost server needed
- SSH/remote friendly

### Option 3: Service Account

**How it works:**
1. IT provisions service account
2. Credentials stored in Keychain/Credential Manager
3. ContextFort authenticates as service account
4. Gets token for user context

**Benefits:**
- No user interaction
- Automated deployments
- Centralized management

## Okta Integration

### Prerequisites

1. Okta organization (e.g., `company.okta.com`)
2. Admin access to create application
3. API token (for automation)

### Setup Steps

#### 1. Create OIDC Application in Okta

1. Log into Okta Admin Console
2. Applications → Create App Integration
3. Sign-in method: **OIDC - OpenID Connect**
4. Application type: **Native Application**
5. App integration name: **ContextFort**
6. Grant types:
   - ✅ Authorization Code
   - ✅ Refresh Token
   - ✅ Device Authorization (optional)
7. Sign-in redirect URIs:
   - `http://localhost:8080/callback`
   - `http://127.0.0.1:8080/callback`
8. Controlled access: **Allow everyone in your organization**
9. Save

#### 2. Configure ContextFort

Create `config/sso-config.json`:

```json
{
  "provider": "okta",
  "okta": {
    "domain": "company.okta.com",
    "client_id": "0oa1234567890abcde",
    "redirect_uri": "http://localhost:8080/callback",
    "scopes": ["openid", "profile", "email", "offline_access"]
  },
  "token_storage": "keychain",
  "token_refresh_margin": 300
}
```

#### 3. Test Authentication

```bash
# Run SSO test script
./bin/test-sso.sh --provider okta

# Should open browser to Okta login
# After login, displays token info
```

### Okta API Endpoints

```
Authorization: https://{domain}/oauth2/v1/authorize
Token:         https://{domain}/oauth2/v1/token
UserInfo:      https://{domain}/oauth2/v1/userinfo
Logout:        https://{domain}/oauth2/v1/logout
```

## Azure AD Integration

### Prerequisites

1. Azure AD tenant (e.g., `company.onmicrosoft.com`)
2. Global Administrator or Application Administrator role
3. Azure subscription (for app registration)

### Setup Steps

#### 1. Register Application in Azure AD

1. Azure Portal → Azure Active Directory → App registrations
2. New registration
3. Name: **ContextFort**
4. Supported account types: **Accounts in this organizational directory only**
5. Redirect URI:
   - Platform: **Public client/native**
   - URI: `http://localhost:8080`
6. Register

#### 2. Configure API Permissions

1. API permissions → Add a permission
2. Microsoft Graph → Delegated permissions
3. Add:
   - `User.Read`
   - `openid`
   - `profile`
   - `email`
   - `offline_access`
4. Grant admin consent

#### 3. Configure ContextFort

Create `config/sso-config.json`:

```json
{
  "provider": "azure",
  "azure": {
    "tenant_id": "12345678-1234-1234-1234-123456789012",
    "client_id": "87654321-4321-4321-4321-210987654321",
    "redirect_uri": "http://localhost:8080",
    "scopes": [
      "https://graph.microsoft.com/User.Read",
      "openid",
      "profile",
      "email",
      "offline_access"
    ]
  },
  "token_storage": "encrypted_file",
  "token_refresh_margin": 300
}
```

#### 4. Test Authentication

```bash
# Run SSO test script
./bin/test-sso.sh --provider azure

# Should open browser to Microsoft login
# After login, displays token info
```

### Azure AD Endpoints

```
Authorization: https://login.microsoftonline.com/{tenant}/oauth2/v2.0/authorize
Token:         https://login.microsoftonline.com/{tenant}/oauth2/v2.0/token
UserInfo:      https://graph.microsoft.com/v1.0/me
```

## Token Storage Options

### Option 1: OS Keychain (Recommended)

**macOS:**
```bash
# Store token in Keychain
security add-generic-password \
  -s "ContextFort" \
  -a "sso-token" \
  -w "<access_token>" \
  -U

# Retrieve token
security find-generic-password \
  -s "ContextFort" \
  -a "sso-token" \
  -w
```

**Windows:**
```powershell
# Store token in Credential Manager
cmdkey /generic:ContextFort /user:sso-token /pass:<access_token>

# Retrieve token
$cred = Get-StoredCredential -Target "ContextFort"
$cred.GetNetworkCredential().Password
```

**Linux:**
```bash
# Use secret-tool (GNOME Keyring)
secret-tool store --label='ContextFort SSO Token' service contextfort username sso-token

# Retrieve
secret-tool lookup service contextfort username sso-token
```

### Option 2: Encrypted File

```bash
# Encrypt token with device key
TOKEN="<access_token>"
DEVICE_KEY=$(uuidgen | shasum -a 256 | cut -d' ' -f1)

echo -n "$TOKEN" | openssl enc -aes-256-cbc \
  -k "$DEVICE_KEY" \
  -pbkdf2 \
  -out ~/.contextfort/sso-token.enc

# Decrypt
openssl enc -d -aes-256-cbc \
  -k "$DEVICE_KEY" \
  -pbkdf2 \
  -in ~/.contextfort/sso-token.enc
```

### Option 3: Environment Variable (Dev Only)

```bash
export CONTEXTFORT_SSO_TOKEN="<access_token>"

# Auto-refresh via background process
./bin/sso-token-refresher.sh &
```

## Token Refresh

Tokens expire (typically 1 hour). Refresh tokens allow getting new tokens without re-authentication.

### Automatic Refresh

```javascript
// In native-messaging-proxy
async function getValidToken() {
  const token = await loadToken();

  // Check expiration
  if (token.expires_at - Date.now() < 300000) { // 5 min margin
    // Refresh token
    const newToken = await refreshAccessToken(token.refresh_token);
    await saveToken(newToken);
    return newToken;
  }

  return token;
}

async function refreshAccessToken(refreshToken) {
  const response = await fetch(tokenEndpoint, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: clientId
    })
  });

  return await response.json();
}
```

## Security Considerations

### ✅ Best Practices

1. **Use PKCE** - Proof Key for Code Exchange prevents auth code interception
2. **Store refresh tokens securely** - Use OS keychain, never plaintext
3. **Rotate tokens** - Refresh before expiration
4. **Revoke on logout** - Call IdP logout endpoint
5. **Encrypt at rest** - Even in keychain, additional encryption helps
6. **Audit token usage** - Log to SIEM when tokens accessed
7. **Limit scopes** - Request minimum permissions needed
8. **Device binding** - Tie tokens to specific device/user

### ⚠️ Security Risks

❌ **Don't store client secrets** - Native apps can't keep secrets
❌ **Don't use implicit flow** - Deprecated, use authorization code + PKCE
❌ **Don't trust localhost** - Can be hijacked, use state parameter
❌ **Don't skip TLS validation** - Always verify SSL certificates
❌ **Don't log tokens** - Redact from logs and error messages

## MDM Configuration

### Jamf Pro

**Configuration Profile:**
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>PayloadContent</key>
    <array>
        <dict>
            <key>PayloadType</key>
            <string>com.contextfort.sso</string>
            <key>PayloadVersion</key>
            <integer>1</integer>
            <key>PayloadIdentifier</key>
            <string>com.contextfort.sso.config</string>
            <key>sso_provider</key>
            <string>okta</string>
            <key>sso_domain</key>
            <string>company.okta.com</string>
            <key>sso_client_id</key>
            <string>0oa1234567890abcde</string>
        </dict>
    </array>
</dict>
</plist>
```

### Intune

**Custom OMA-URI:**
```xml
OMA-URI: ./Device/Vendor/MSFT/Policy/Config/ContextFort/SSOConfig
Data type: String
Value: {"provider":"azure","tenant_id":"...","client_id":"..."}
```

## Troubleshooting

### Token Not Refreshing

**Symptom:** User must re-login frequently

**Causes:**
- Refresh token expired (typically 90 days)
- IdP revoked token
- Token refresh API call failing

**Fix:**
```bash
# Check token expiration
./bin/check-sso-token.sh

# Manually refresh
./bin/refresh-sso-token.sh

# Clear and re-authenticate
./bin/clear-sso-token.sh
./bin/test-sso.sh
```

### Browser Not Opening

**Symptom:** SSO flow doesn't launch browser

**Causes:**
- No default browser set
- Browser blocked by firewall
- Desktop environment not detected

**Fix:**
```bash
# Force browser selection
export BROWSER=firefox
./bin/test-sso.sh

# Or use device code flow
./bin/test-sso.sh --device-code
```

### Token Storage Failed

**Symptom:** "Error saving token to keychain"

**Causes:**
- Keychain locked (macOS)
- Credential Manager permissions (Windows)
- Secret service not running (Linux)

**Fix:**
```bash
# macOS: Unlock keychain
security unlock-keychain

# Linux: Start secret service
gnome-keyring-daemon --start

# Windows: Check Credential Manager service
sc query VaultSvc
```

## References

- [Okta OIDC Documentation](https://developer.okta.com/docs/guides/implement-grant-type/authcode/main/)
- [Azure AD OAuth Documentation](https://docs.microsoft.com/en-us/azure/active-directory/develop/v2-oauth2-auth-code-flow)
- [OAuth 2.0 Best Practices](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-security-topics)
- [PKCE Specification](https://datatracker.ietf.org/doc/html/rfc7636)
