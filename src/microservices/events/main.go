package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/segmentio/kafka-go"
)

const (
	movieTopic   = "movie-events"
	userTopic    = "user-events"
	paymentTopic = "payment-events"
)

type app struct {
	brokers []string
}

type eventEnvelope struct {
	ID        string      `json:"id"`
	Type      string      `json:"type"`
	Timestamp string      `json:"timestamp"`
	Payload   interface{} `json:"payload"`
}

type eventResponse struct {
	Status    string        `json:"status"`
	Partition int           `json:"partition"`
	Offset    int64         `json:"offset"`
	Event     eventEnvelope `json:"event"`
}

type errorResponse struct {
	Error string `json:"error"`
}

type movieEvent struct {
	MovieID     int      `json:"movie_id"`
	Title       string   `json:"title"`
	Action      string   `json:"action"`
	UserID      int      `json:"user_id,omitempty"`
	Rating      float64  `json:"rating,omitempty"`
	Genres      []string `json:"genres,omitempty"`
	Description string   `json:"description,omitempty"`
}

type userEvent struct {
	UserID    int    `json:"user_id"`
	Username  string `json:"username,omitempty"`
	Email     string `json:"email,omitempty"`
	Action    string `json:"action"`
	Timestamp string `json:"timestamp"`
}

type paymentEvent struct {
	PaymentID  int     `json:"payment_id"`
	UserID     int     `json:"user_id"`
	Amount     float64 `json:"amount"`
	Status     string  `json:"status"`
	Timestamp  string  `json:"timestamp"`
	MethodType string  `json:"method_type,omitempty"`
}

func main() {
	app := &app{
		brokers: parseBrokers(getEnv("KAFKA_BROKERS", "localhost:9092")),
	}

	go app.consumeTopic(movieTopic)
	go app.consumeTopic(userTopic)
	go app.consumeTopic(paymentTopic)

	mux := http.NewServeMux()
	mux.HandleFunc("/api/events/health", healthHandler)
	mux.HandleFunc("/api/events/movie", app.handleMovieEvent)
	mux.HandleFunc("/api/events/user", app.handleUserEvent)
	mux.HandleFunc("/api/events/payment", app.handlePaymentEvent)

	port := getEnv("PORT", "8082")
	log.Printf("Starting events service on port %s", port)
	log.Printf("Kafka brokers: %s", strings.Join(app.brokers, ","))

	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	writeJSON(w, http.StatusOK, map[string]bool{"status": true})
}

func (a *app) handleMovieEvent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var payload movieEvent
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if payload.MovieID == 0 || payload.Title == "" || payload.Action == "" {
		writeError(w, http.StatusBadRequest, "movie_id, title and action are required")
		return
	}

	response, err := a.publishEvent(movieTopic, "movie", payload)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, response)
}

func (a *app) handleUserEvent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var payload userEvent
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if payload.UserID == 0 || payload.Action == "" || payload.Timestamp == "" {
		writeError(w, http.StatusBadRequest, "user_id, action and timestamp are required")
		return
	}

	response, err := a.publishEvent(userTopic, "user", payload)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, response)
}

func (a *app) handlePaymentEvent(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		writeError(w, http.StatusMethodNotAllowed, "Method not allowed")
		return
	}

	var payload paymentEvent
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if payload.PaymentID == 0 || payload.UserID == 0 || payload.Amount == 0 || payload.Status == "" || payload.Timestamp == "" {
		writeError(w, http.StatusBadRequest, "payment_id, user_id, amount, status and timestamp are required")
		return
	}

	response, err := a.publishEvent(paymentTopic, "payment", payload)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}

	writeJSON(w, http.StatusCreated, response)
}

func (a *app) publishEvent(topic, eventType string, payload interface{}) (*eventResponse, error) {
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	envelope := eventEnvelope{
		ID:        buildEventID(eventType),
		Type:      eventType,
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Payload:   payload,
	}

	rawMessage, err := json.Marshal(envelope)
	if err != nil {
		return nil, fmt.Errorf("marshal event: %w", err)
	}

	conn, err := kafka.DialLeader(ctx, "tcp", a.brokers[0], topic, 0)
	if err != nil {
		return nil, fmt.Errorf("dial kafka leader for topic %s: %w", topic, err)
	}
	defer conn.Close()

	if err := conn.SetWriteDeadline(time.Now().Add(10 * time.Second)); err != nil {
		return nil, fmt.Errorf("set write deadline: %w", err)
	}

	offsetBeforeWrite, err := conn.ReadLastOffset()
	if err != nil {
		return nil, fmt.Errorf("read last offset for topic %s: %w", topic, err)
	}

	_, err = conn.WriteMessages(kafka.Message{
		Time:  time.Now().UTC(),
		Value: rawMessage,
	})
	if err != nil {
		return nil, fmt.Errorf("write message to topic %s: %w", topic, err)
	}

	return &eventResponse{
		Status:    "success",
		Partition: 0,
		Offset:    offsetBeforeWrite,
		Event:     envelope,
	}, nil
}

func (a *app) consumeTopic(topic string) {
	reader := kafka.NewReader(kafka.ReaderConfig{
		Brokers:     a.brokers,
		Topic:       topic,
		GroupID:     "events-service-" + topic,
		StartOffset: kafka.LastOffset,
		MinBytes:    1,
		MaxBytes:    10e6,
		MaxWait:     time.Second,
	})
	defer reader.Close()

	for {
		message, err := reader.ReadMessage(context.Background())
		if err != nil {
			log.Printf("Kafka consumer error for topic %s: %v", topic, err)
			time.Sleep(2 * time.Second)
			continue
		}

		log.Printf("Processed event from topic=%s partition=%d offset=%d payload=%s",
			topic, message.Partition, message.Offset, string(message.Value))
	}
}

func parseBrokers(raw string) []string {
	parts := strings.Split(raw, ",")
	brokers := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			brokers = append(brokers, trimmed)
		}
	}
	if len(brokers) == 0 {
		return []string{"localhost:9092"}
	}
	return brokers
}

func buildEventID(eventType string) string {
	return fmt.Sprintf("%s-%d", eventType, time.Now().UTC().UnixNano())
}

func getEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func writeJSON(w http.ResponseWriter, status int, payload interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("failed to encode response: %v", err)
	}
}

func writeError(w http.ResponseWriter, status int, message string) {
	writeJSON(w, status, errorResponse{Error: message})
}
