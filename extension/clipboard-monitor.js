/**
 * ContextFort Clipboard Monitor
 * DLP-style monitoring for copy/paste operations
 */

// DLP patterns to detect
const DLP_PATTERNS = {
  ssn: {
    regex: /\b\d{3}-\d{2}-\d{4}\b/g,
    name: 'Social Security Number',
    severity: 'high'
  },
  credit_card: {
    regex: /\b(?:\d{4}[-\s]?){3}\d{4}\b/g,
    name: 'Credit Card Number',
    severity: 'high'
  },
  api_key: {
    regex: /\b[A-Za-z0-9]{32,}\b/g,
    name: 'API Key (potential)',
    severity: 'medium'
  },
  aws_key: {
    regex: /AKIA[0-9A-Z]{16}/g,
    name: 'AWS Access Key',
    severity: 'high'
  },
  private_key: {
    regex: /-----BEGIN (RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----/g,
    name: 'Private Key',
    severity: 'critical'
  },
  jwt: {
    regex: /eyJ[A-Za-z0-9_-]+\.eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/g,
    name: 'JWT Token',
    severity: 'medium'
  },
  email: {
    regex: /\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b/g,
    name: 'Email Address',
    severity: 'low'
  },
  ipv4: {
    regex: /\b(?:\d{1,3}\.){3}\d{1,3}\b/g,
    name: 'IPv4 Address',
    severity: 'low'
  }
};

// Configuration (loaded from storage)
let config = {
  enabled: true,
  blockMode: false, // true = block, false = log only
  patterns: Object.keys(DLP_PATTERNS)
};

// Load configuration
chrome.storage.local.get(['dlpConfig'], (result) => {
  if (result.dlpConfig) {
    config = { ...config, ...result.dlpConfig };
  }
});

// Listen for config changes
chrome.storage.onChanged.addListener((changes, area) => {
  if (area === 'local' && changes.dlpConfig) {
    config = { ...config, ...changes.dlpConfig.newValue };
  }
});

/**
 * Scan text for sensitive data patterns
 */
function scanText(text) {
  if (!text || !config.enabled) {
    return [];
  }

  const findings = [];

  for (const patternName of config.patterns) {
    const pattern = DLP_PATTERNS[patternName];
    if (!pattern) continue;

    const matches = text.match(pattern.regex);
    if (matches) {
      findings.push({
        pattern: patternName,
        name: pattern.name,
        severity: pattern.severity,
        count: matches.length,
        preview: matches[0].substring(0, 20) + '...'
      });
    }
  }

  return findings;
}

/**
 * Log DLP event to background script
 */
function logDlpEvent(eventType, findings, action = 'logged') {
  try {
    chrome.runtime.sendMessage({
      type: 'DLP_EVENT',
      eventType,
      findings,
      action,
      url: window.location.href,
      title: document.title,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('[ContextFort DLP] Error logging event:', error);
  }
}

/**
 * Show notification to user
 */
function showDlpNotification(findings, blocked = false) {
  const title = blocked ? '⛔ Data Copy Blocked' : '⚠️ Sensitive Data Detected';
  const severeFindings = findings.filter(f => f.severity === 'high' || f.severity === 'critical');
  const message = severeFindings.length > 0
    ? `Detected: ${severeFindings.map(f => f.name).join(', ')}`
    : `Detected ${findings.length} potential sensitive data pattern(s)`;

  try {
    chrome.runtime.sendMessage({
      type: 'SHOW_NOTIFICATION',
      title,
      message,
      notificationType: blocked ? 'error' : 'warning'
    });
  } catch (error) {
    console.error('[ContextFort DLP] Error showing notification:', error);
  }
}

/**
 * Monitor copy events
 */
document.addEventListener('copy', (event) => {
  if (!config.enabled) return;

  try {
    // Get copied text
    const selection = window.getSelection();
    const copiedText = selection ? selection.toString() : '';

    if (!copiedText || copiedText.length === 0) return;

    // Scan for sensitive data
    const findings = scanText(copiedText);

    if (findings.length > 0) {
      const hasCritical = findings.some(f => f.severity === 'critical' || f.severity === 'high');

      // Block if in block mode and critical findings
      if (config.blockMode && hasCritical) {
        event.preventDefault();
        event.stopPropagation();

        logDlpEvent('copy', findings, 'blocked');
        showDlpNotification(findings, true);
      } else {
        // Log but allow
        logDlpEvent('copy', findings, 'allowed');
        showDlpNotification(findings, false);
      }
    }
  } catch (error) {
    console.error('[ContextFort DLP] Error in copy handler:', error);
  }
}, true);

/**
 * Monitor paste events
 */
document.addEventListener('paste', (event) => {
  if (!config.enabled) return;

  try {
    // Get pasted text
    const clipboardData = event.clipboardData || window.clipboardData;
    const pastedText = clipboardData ? clipboardData.getData('text') : '';

    if (!pastedText || pastedText.length === 0) return;

    // Scan for sensitive data
    const findings = scanText(pastedText);

    if (findings.length > 0) {
      const hasCritical = findings.some(f => f.severity === 'critical' || f.severity === 'high');

      // Block if in block mode and critical findings
      if (config.blockMode && hasCritical) {
        event.preventDefault();
        event.stopPropagation();

        logDlpEvent('paste', findings, 'blocked');
        showDlpNotification(findings, true);
      } else {
        // Log but allow
        logDlpEvent('paste', findings, 'allowed');
        showDlpNotification(findings, false);
      }
    }
  } catch (error) {
    console.error('[ContextFort DLP] Error in paste handler:', error);
  }
}, true);

/**
 * Monitor cut events (same as copy)
 */
document.addEventListener('cut', (event) => {
  if (!config.enabled) return;

  try {
    const selection = window.getSelection();
    const cutText = selection ? selection.toString() : '';

    if (!cutText || cutText.length === 0) return;

    const findings = scanText(cutText);

    if (findings.length > 0) {
      const hasCritical = findings.some(f => f.severity === 'critical' || f.severity === 'high');

      if (config.blockMode && hasCritical) {
        event.preventDefault();
        event.stopPropagation();

        logDlpEvent('cut', findings, 'blocked');
        showDlpNotification(findings, true);
      } else {
        logDlpEvent('cut', findings, 'allowed');
        showDlpNotification(findings, false);
      }
    }
  } catch (error) {
    console.error('[ContextFort DLP] Error in cut handler:', error);
  }
}, true);

// Log initialization
console.log('[ContextFort DLP] Clipboard monitor initialized');
