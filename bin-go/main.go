package main

import (
	"encoding/binary"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"time"
)

// Configuration
const (
	RealNativeHost  = "/Applications/Claude.app/Contents/Helpers/chrome-native-host"
	ContextFortDir  = ".contextfort"
	LogFile         = "logs/native-proxy.log"
	JSONLogFile     = "logs/native-proxy-events.jsonl"
)

// Proxy session
type ProxySession struct {
	SessionID     string    `json:"proxy_session_id"`
	PID           int       `json:"proxy_pid"`
	StartTime     time.Time `json:"start_time"`
	MessageCount  int       `json:"message_count"`
}

// JSON log event
type LogEvent struct {
	Timestamp   string      `json:"timestamp"`
	EventType   string      `json:"event_type"`
	SessionID   string      `json:"proxy_session_id"`
	PID         int         `json:"proxy_pid"`
	Data        interface{} `json:"data,omitempty"`
}

var (
	session     *ProxySession
	textLog     *os.File
	jsonLog     *os.File
)

func init() {
	// Initialize session
	session = &ProxySession{
		SessionID: fmt.Sprintf("proxy-%d-%d", time.Now().Unix(), os.Getpid()),
		PID:       os.Getpid(),
		StartTime: time.Now(),
	}

	// Setup logging
	homeDir, _ := os.UserHomeDir()
	contextfortDir := filepath.Join(homeDir, ContextFortDir)
	logsDir := filepath.Join(contextfortDir, "logs")
	os.MkdirAll(logsDir, 0755)

	textLog, _ = os.OpenFile(filepath.Join(logsDir, "native-proxy.log"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
	jsonLog, _ = os.OpenFile(filepath.Join(logsDir, "native-proxy-events.jsonl"), os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0644)
}

func main() {
	defer cleanup()

	logText("=== ContextFort Native Messaging Proxy (Go) Started ===")
	logEvent("proxy_start", map[string]interface{}{
		"real_native_host": RealNativeHost,
	})

	// Check and launch ContextFort Chrome
	if !isContextFortRunning() {
		logText("ContextFort Chrome not running, launching...")
		if err := launchContextFortChrome(); err != nil {
			logText("Error launching Chrome: " + err.Error())
			os.Exit(1)
		}
		logText("ContextFort Chrome started")
		time.Sleep(2 * time.Second) // Wait for Chrome to initialize
	} else {
		logText("ContextFort Chrome already running")
	}

	// Spawn real native host
	cmd := exec.Command(RealNativeHost)
	stdin, err := cmd.StdinPipe()
	if err != nil {
		logText("Error creating stdin pipe: " + err.Error())
		os.Exit(1)
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		logText("Error creating stdout pipe: " + err.Error())
		os.Exit(1)
	}

	if err := cmd.Start(); err != nil {
		logText("Error starting real host: " + err.Error())
		os.Exit(1)
	}

	logText("Real native host spawned (PID: " + fmt.Sprint(cmd.Process.Pid) + ")")
	logEvent("real_host_spawn", map[string]interface{}{
		"real_host_pid": cmd.Process.Pid,
	})

	// Bidirectional forwarding
	errChan := make(chan error, 2)

	// Extension -> Proxy -> Real Host
	go func() {
		err := forwardMessages(os.Stdin, stdin, "extension", "host")
		errChan <- err
	}()

	// Real Host -> Proxy -> Extension
	go func() {
		err := forwardMessages(stdout, os.Stdout, "host", "extension")
		errChan <- err
	}()

	// Wait for error or completion
	err = <-errChan
	if err != nil {
		logText("Forwarding error: " + err.Error())
	}

	cmd.Wait()
	logText("Proxy exiting")
}

func forwardMessages(reader io.Reader, writer io.Writer, from, to string) error {
	messageID := 0

	for {
		messageID++

		// Read native messaging message (length-prefixed JSON)
		var length uint32
		if err := binary.Read(reader, binary.LittleEndian, &length); err != nil {
			if err == io.EOF {
				return nil
			}
			return fmt.Errorf("error reading message length: %v", err)
		}

		// Read message content
		messageBytes := make([]byte, length)
		if _, err := io.ReadFull(reader, messageBytes); err != nil {
			return fmt.Errorf("error reading message content: %v", err)
		}

		// Parse JSON
		var message map[string]interface{}
		if err := json.Unmarshal(messageBytes, &message); err != nil {
			return fmt.Errorf("error parsing message JSON: %v", err)
		}

		// Log
		messageType := "unknown"
		if t, ok := message["type"].(string); ok {
			messageType = t
		}

		logText(fmt.Sprintf("Message %d from %s: type=%s, size=%d", messageID, from, messageType, length))
		logEvent(fmt.Sprintf("message_from_%s", from), map[string]interface{}{
			"message_id":   messageID,
			"message_type": messageType,
			"message_size": length,
		})

		// Forward message
		if err := binary.Write(writer, binary.LittleEndian, length); err != nil {
			return fmt.Errorf("error writing message length: %v", err)
		}
		if _, err := writer.Write(messageBytes); err != nil {
			return fmt.Errorf("error writing message content: %v", err)
		}

		logEvent(fmt.Sprintf("message_forwarded_to_%s", to), map[string]interface{}{
			"message_id": messageID,
		})

		session.MessageCount++
	}
}

func isContextFortRunning() bool {
	pidFiles, err := filepath.Glob("/tmp/contextfort-*.pid")
	if err != nil || len(pidFiles) == 0 {
		return false
	}

	// Check if any PID is still running
	for _, pidFile := range pidFiles {
		pidBytes, err := os.ReadFile(pidFile)
		if err != nil {
			continue
		}

		// Check if process exists (platform-specific)
		// For now, assume exists if PID file exists
		// TODO: Add proper process check
		_ = pidBytes
		return true
	}

	return false
}

func launchContextFortChrome() error {
	pluginDir := os.Getenv("CONTEXTFORT_PLUGIN_DIR")
	if pluginDir == "" {
		homeDir, _ := os.UserHomeDir()
		pluginDir = filepath.Join(homeDir, "agents-blocker", "plugin")
	}

	launchScript := filepath.Join(pluginDir, "bin", "launch-chrome.sh")
	cmd := exec.Command(launchScript)
	cmd.Env = append(os.Environ(), "CLAUDE_PLUGIN_ROOT="+pluginDir)

	logEvent("chrome_launched", map[string]interface{}{
		"launch_script": launchScript,
	})

	return cmd.Start()
}

func logText(message string) {
	timestamp := time.Now().Format(time.RFC3339)
	logLine := fmt.Sprintf("[%s] %s\n", timestamp, message)

	if textLog != nil {
		textLog.WriteString(logLine)
	}

	log.Print(message)
}

func logEvent(eventType string, data interface{}) {
	event := LogEvent{
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		EventType: eventType,
		SessionID: session.SessionID,
		PID:       session.PID,
		Data:      data,
	}

	if jsonLog != nil {
		eventJSON, _ := json.Marshal(event)
		jsonLog.Write(eventJSON)
		jsonLog.WriteString("\n")
	}
}

func cleanup() {
	logText("Proxy cleanup")
	logEvent("proxy_exit", map[string]interface{}{
		"message_count": session.MessageCount,
		"duration_seconds": time.Since(session.StartTime).Seconds(),
	})

	if textLog != nil {
		textLog.Close()
	}
	if jsonLog != nil {
		jsonLog.Close()
	}
}
