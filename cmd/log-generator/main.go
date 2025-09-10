package main

import (
	"encoding/json"
	"fmt"
	"log"
	"math/rand"
	"os"
	"path/filepath"
	"time"

	"github.com/google/uuid"
)

type StructuredLog struct {
	Timestamp  string `json:"timestamp"`
	Level      string `json:"level"`
	Message    string `json:"message"`
	RequestID  string `json:"request_id"`
	LatencyMs  int    `json:"latency_ms"`
	StatusCode int    `json:"status_code"`
}

func main() {
	logDir := "/var/log/custom"
	structuredLogPath := filepath.Join(logDir, "structured.log")
	plainLogPath := filepath.Join(logDir, "plain.log")
	errorLogPath := filepath.Join(logDir, "error.log")

	// Create log directory if it doesn't exist
	if err := os.MkdirAll(logDir, os.ModePerm); err != nil {
		log.Fatalf("Failed to create log directory: %v", err)
	}

	// Open log files
	structuredFile, err := os.OpenFile(structuredLogPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open structured log file: %v", err)
	}
	defer structuredFile.Close()

	plainFile, err := os.OpenFile(plainLogPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open plain log file: %v", err)
	}
	defer plainFile.Close()

	errorFile, err := os.OpenFile(errorLogPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		log.Fatalf("Failed to open error log file: %v", err)
	}
	defer errorFile.Close()

	// Initialize random seed
	rand.Seed(time.Now().UnixNano())

	// Start goroutines for log generation
	go generateStructuredLogs(structuredFile)
	go generatePlainLogs(plainFile)
	go generateErrorLogs(errorFile)

	// Keep the program running
	select {}
}

func generateStructuredLogs(file *os.File) {
	for {
		logEntry := StructuredLog{
			Timestamp:  time.Now().UTC().Format(time.RFC3339Nano),
			Level:      "INFO",
			Message:    "Request processed",
			RequestID:  uuid.New().String(),
			LatencyMs:  rand.Intn(1000),
			StatusCode: 200 + rand.Intn(5),
		}

		jsonData, err := json.Marshal(logEntry)
		if err != nil {
			log.Printf("Error marshaling JSON: %v", err)
			continue
		}

		if _, err := file.WriteString(string(jsonData) + "\n"); err != nil {
			log.Printf("Error writing to structured log file: %v", err)
		}

		time.Sleep(500 * time.Millisecond)
	}
}

func generatePlainLogs(file *os.File) {
	for {
		timestamp := time.Now().Format("2006-01-02 15:04:05")
		logLine := fmt.Sprintf("[%s] [INFO] User activity recorded. Session: %s\n", timestamp, uuid.New().String())

		if _, err := file.WriteString(logLine); err != nil {
			log.Printf("Error writing to plain log file: %v", err)
		}

		time.Sleep(1200 * time.Millisecond)
	}
}

func generateErrorLogs(file *os.File) {
	errorTypes := []string{
		"Connection timeout",
		"Database unavailable",
		"Authentication failed",
		"Permission denied",
		"Resource not found",
	}

	for {
		timestamp := time.Now().Format("2006-01-02 15:04:05")
		errorType := errorTypes[rand.Intn(len(errorTypes))]

		// Generate a random error reference code
		b := make([]byte, 4)
		rand.Read(b)
		errorRef := fmt.Sprintf("ERR-%x", b)

		logLine := fmt.Sprintf("[%s] [ERROR] %s. Reference: %s\n", timestamp, errorType, errorRef)

		if _, err := file.WriteString(logLine); err != nil {
			log.Printf("Error writing to error log file: %v", err)
		}

		time.Sleep(5 * time.Second)
	}
}
