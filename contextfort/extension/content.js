/**
 * ContextFort Stage 1 Extension - Content Script
 * Detects AI agents operating in the page
 */

// Detect Claude agent
function detectClaudeAgent() {
  // Check for Claude CDP connection indicators
  const hasCDP = window.navigator.webdriver ||
                 window.__playwright ||
                 window.__puppeteer;

  // Check for Claude-specific patterns
  const isClaudePage = window.location.href.includes('claude.ai') ||
                       window.location.href.includes('anthropic.com');

  if (hasCDP && !isClaudePage) {
    return 'claude';
  }

  return null;
}

// Detect ChatGPT agent
function detectChatGPTAgent() {
  // Check for OpenAI patterns
  const hasOpenAIIndicators = document.querySelector('[data-testid*="openai"]') ||
                              document.body.textContent.includes('ChatGPT');

  if (window.navigator.webdriver && hasOpenAIIndicators) {
    return 'chatgpt';
  }

  return null;
}

// Check for agent on page load
window.addEventListener('load', () => {
  const claudeAgent = detectClaudeAgent();
  const chatgptAgent = detectChatGPTAgent();

  const detectedAgent = claudeAgent || chatgptAgent;

  if (detectedAgent) {
    console.log('[ContextFort] Agent detected:', detectedAgent);

    chrome.runtime.sendMessage({
      type: 'agent_detected',
      source: detectedAgent,
      url: window.location.href
    });
  }
});

// Monitor for agents joining after page load
const observer = new MutationObserver(() => {
  const claudeAgent = detectClaudeAgent();
  const chatgptAgent = detectChatGPTAgent();

  const detectedAgent = claudeAgent || chatgptAgent;

  if (detectedAgent) {
    chrome.runtime.sendMessage({
      type: 'agent_detected',
      source: detectedAgent,
      url: window.location.href
    });
  }
});

observer.observe(document.body, {
  childList: true,
  subtree: true
});

console.log('[ContextFort] Content script injected');
