#!/usr/bin/env node
/**
 * ContextFort Native Messaging Proxy
 *
 * Intercepts Claude-in-Chrome native messaging and launches ContextFort Chrome
 * Works for both Claude Desktop app and Claude Code
 */

const { spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

// Configuration
const PLUGIN_DIR = process.env.CONTEXTFORT_PLUGIN_DIR || path.join(__dirname, '..');
const REAL_NATIVE_HOST = '/Applications/Claude.app/Contents/Helpers/chrome-native-host';
const CONTEXTFORT_DIR = path.join(process.env.HOME, '.contextfort');
const LOG_FILE = path.join(CONTEXTFORT_DIR, 'logs', 'native-proxy.log');
const JSON_LOG_FILE = path.join(CONTEXTFORT_DIR, 'logs', 'native-proxy-events.jsonl');

// Ensure log directory exists
fs.mkdirSync(path.dirname(LOG_FILE), { recursive: true });

// Session ID for this proxy instance
const PROXY_SESSION_ID = `proxy-${Date.now()}-${process.pid}`;

// Text logging (human-readable)
function log(message) {
  const timestamp = new Date().toISOString();
  const logMessage = `[${timestamp}] ${message}\n`;
  fs.appendFileSync(LOG_FILE, logMessage);
}

// Structured JSON logging for SIEM
function logEvent(eventType, data = {}) {
  const event = {
    timestamp: new Date().toISOString(),
    event_type: eventType,
    proxy_session_id: PROXY_SESSION_ID,
    proxy_pid: process.pid,
    ...data
  };

  // Write as JSON Lines format (one JSON object per line)
  fs.appendFileSync(JSON_LOG_FILE, JSON.stringify(event) + '\n');
}

log('=== ContextFort Native Messaging Proxy Started ===');
logEvent('proxy_start', {
  plugin_dir: PLUGIN_DIR,
  real_native_host: REAL_NATIVE_HOST
});

// Check if ContextFort Chrome is running
function isContextFortRunning() {
  try {
    const pidFiles = fs.readdirSync('/tmp').filter(f => f.startsWith('contextfort-') && f.endsWith('.pid'));

    for (const pidFile of pidFiles) {
      const pid = fs.readFileSync(path.join('/tmp', pidFile), 'utf8').trim();
      try {
        process.kill(pid, 0); // Check if process exists
        return true;
      } catch (e) {
        // Process doesn't exist, clean up stale PID file
        fs.unlinkSync(path.join('/tmp', pidFile));
      }
    }
    return false;
  } catch (e) {
    return false;
  }
}

// Launch ContextFort Chrome
function launchContextFortChrome() {
  log('Launching ContextFort Chrome...');

  const launchScript = path.join(PLUGIN_DIR, 'bin', 'launch-chrome.sh');

  const child = spawn(launchScript, [], {
    env: {
      ...process.env,
      CLAUDE_PLUGIN_ROOT: PLUGIN_DIR
    },
    detached: true,
    stdio: 'ignore'
  });

  child.unref();

  log(`ContextFort Chrome launched (PID: ${child.pid})`);
  logEvent('chrome_launched', {
    chrome_pid: child.pid,
    launch_script: launchScript
  });

  // Wait a bit for Chrome to start
  return new Promise(resolve => setTimeout(resolve, 2000));
}

// Native Messaging Protocol
// Messages are length-prefixed JSON
function readMessage(stream) {
  return new Promise((resolve, reject) => {
    const lengthBuffer = Buffer.alloc(4);
    let bytesRead = 0;

    function readLength() {
      const chunk = stream.read(4 - bytesRead);
      if (chunk === null) {
        stream.once('readable', readLength);
        return;
      }

      chunk.copy(lengthBuffer, bytesRead);
      bytesRead += chunk.length;

      if (bytesRead === 4) {
        const messageLength = lengthBuffer.readUInt32LE(0);
        readContent(messageLength);
      } else {
        stream.once('readable', readLength);
      }
    }

    function readContent(length) {
      const contentBuffer = Buffer.alloc(length);
      let contentBytesRead = 0;

      function readChunk() {
        const chunk = stream.read(length - contentBytesRead);
        if (chunk === null) {
          stream.once('readable', readChunk);
          return;
        }

        chunk.copy(contentBuffer, contentBytesRead);
        contentBytesRead += chunk.length;

        if (contentBytesRead === length) {
          try {
            const message = JSON.parse(contentBuffer.toString('utf8'));
            resolve(message);
          } catch (e) {
            reject(new Error('Invalid JSON message'));
          }
        } else {
          stream.once('readable', readChunk);
        }
      }

      readChunk();
    }

    readLength();
  });
}

function writeMessage(stream, message) {
  const content = JSON.stringify(message);
  const contentBuffer = Buffer.from(content, 'utf8');
  const lengthBuffer = Buffer.alloc(4);
  lengthBuffer.writeUInt32LE(contentBuffer.length, 0);

  stream.write(lengthBuffer);
  stream.write(contentBuffer);
}

// Main proxy logic
async function main() {
  try {
    // Check and launch ContextFort Chrome if needed
    if (!isContextFortRunning()) {
      log('ContextFort Chrome not running, launching...');
      logEvent('chrome_check', { status: 'not_running' });
      await launchContextFortChrome();
      log('ContextFort Chrome started successfully');
      logEvent('chrome_check', { status: 'started' });
    } else {
      log('ContextFort Chrome already running');
      logEvent('chrome_check', { status: 'already_running' });
    }

    // Spawn the real native host
    log('Spawning real native host...');
    const realHost = spawn(REAL_NATIVE_HOST, [], {
      stdio: ['pipe', 'pipe', 'pipe']
    });

    log('Real native host spawned');
    logEvent('real_host_spawn', {
      real_host_path: REAL_NATIVE_HOST,
      real_host_pid: realHost.pid
    });

    // Forward stderr from real host to our log
    realHost.stderr.on('data', (data) => {
      const stderrData = data.toString();
      log(`[Real Host stderr] ${stderrData}`);
      logEvent('real_host_stderr', {
        data: stderrData.substring(0, 500)
      });
    });

    realHost.on('error', (error) => {
      log(`Real host error: ${error.message}`);
      logEvent('real_host_error', {
        error: error.message,
        stack: error.stack
      });
      process.exit(1);
    });

    realHost.on('exit', (code) => {
      log(`Real host exited with code ${code}`);
      logEvent('real_host_exit', {
        exit_code: code
      });
      process.exit(code || 0);
    });

    // Bidirectional forwarding
    // Extension -> Proxy -> Real Host
    let messageCountToHost = 0;
    (async () => {
      try {
        while (true) {
          const message = await readMessage(process.stdin);
          messageCountToHost++;

          const messageStr = JSON.stringify(message);
          log(`Received from extension: ${messageStr.substring(0, 200)}...`);

          logEvent('message_from_extension', {
            message_id: messageCountToHost,
            message_type: message.type || 'unknown',
            message_size: messageStr.length,
            message_preview: messageStr.substring(0, 200)
          });

          writeMessage(realHost.stdin, message);

          logEvent('message_forwarded_to_host', {
            message_id: messageCountToHost
          });
        }
      } catch (e) {
        log(`Error reading from extension: ${e.message}`);
        logEvent('extension_read_error', {
          error: e.message,
          stack: e.stack
        });
        realHost.kill();
        process.exit(0);
      }
    })();

    // Real Host -> Proxy -> Extension
    let messageCountFromHost = 0;
    (async () => {
      try {
        while (true) {
          const message = await readMessage(realHost.stdout);
          messageCountFromHost++;

          const messageStr = JSON.stringify(message);
          log(`Received from real host: ${messageStr.substring(0, 200)}...`);

          logEvent('message_from_host', {
            message_id: messageCountFromHost,
            message_type: message.type || 'unknown',
            message_size: messageStr.length,
            message_preview: messageStr.substring(0, 200)
          });

          writeMessage(process.stdout, message);

          logEvent('message_forwarded_to_extension', {
            message_id: messageCountFromHost
          });
        }
      } catch (e) {
        log(`Error reading from real host: ${e.message}`);
        logEvent('host_read_error', {
          error: e.message,
          stack: e.stack
        });
        process.exit(0);
      }
    })();

  } catch (error) {
    log(`Fatal error: ${error.message}`);
    log(error.stack);
    logEvent('fatal_error', {
      error: error.message,
      stack: error.stack
    });
    process.exit(1);
  }
}

// Handle termination
process.on('SIGTERM', () => {
  log('Received SIGTERM, shutting down...');
  logEvent('proxy_shutdown', {
    signal: 'SIGTERM'
  });
  process.exit(0);
});

process.on('SIGINT', () => {
  log('Received SIGINT, shutting down...');
  logEvent('proxy_shutdown', {
    signal: 'SIGINT'
  });
  process.exit(0);
});

process.on('exit', (code) => {
  logEvent('proxy_exit', {
    exit_code: code
  });
});

process.on('SIGINT', () => {
  log('Received SIGINT, shutting down...');
  process.exit(0);
});

// Run
main().catch(error => {
  log(`Unhandled error: ${error.message}`);
  log(error.stack);
  process.exit(1);
});
