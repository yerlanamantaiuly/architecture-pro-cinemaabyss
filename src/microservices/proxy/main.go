package main

import (
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strconv"
	"strings"
	"sync/atomic"
)

type proxyConfig struct {
	monolithURL           *url.URL
	moviesServiceURL      *url.URL
	eventsServiceURL      *url.URL
	gradualMigration      bool
	moviesMigrationPct    uint64
	moviesRequestCounter  atomic.Uint64
}

func main() {
	cfg := loadConfig()

	mux := http.NewServeMux()
	mux.HandleFunc("/health", healthHandler)
	mux.HandleFunc("/api/movies/health", cfg.proxyTo(cfg.moviesServiceURL))
	mux.HandleFunc("/api/movies", cfg.handleMovies)
	mux.HandleFunc("/api/users", cfg.proxyTo(cfg.monolithURL))
	mux.HandleFunc("/api/payments", cfg.proxyTo(cfg.monolithURL))
	mux.HandleFunc("/api/subscriptions", cfg.proxyTo(cfg.monolithURL))
	mux.HandleFunc("/api/events/health", cfg.proxyTo(cfg.eventsServiceURL))
	mux.HandleFunc("/api/events/movie", cfg.proxyTo(cfg.eventsServiceURL))
	mux.HandleFunc("/api/events/user", cfg.proxyTo(cfg.eventsServiceURL))
	mux.HandleFunc("/api/events/payment", cfg.proxyTo(cfg.eventsServiceURL))

	port := os.Getenv("PORT")
	if port == "" {
		port = "8000"
	}

	log.Printf("Starting proxy service on port %s", port)
	log.Printf("Monolith target: %s", cfg.monolithURL)
	log.Printf("Movies target: %s", cfg.moviesServiceURL)
	log.Printf("Events target: %s", cfg.eventsServiceURL)
	log.Printf("Gradual migration: %t, movies migration percent: %d", cfg.gradualMigration, cfg.moviesMigrationPct)

	log.Fatal(http.ListenAndServe(":"+port, mux))
}

func loadConfig() *proxyConfig {
	return &proxyConfig{
		monolithURL:        mustParseURL(getEnv("MONOLITH_URL", "http://localhost:8080")),
		moviesServiceURL:   mustParseURL(getEnv("MOVIES_SERVICE_URL", "http://localhost:8081")),
		eventsServiceURL:   mustParseURL(getEnv("EVENTS_SERVICE_URL", "http://localhost:8082")),
		gradualMigration:   strings.EqualFold(getEnv("GRADUAL_MIGRATION", "true"), "true"),
		moviesMigrationPct: parsePercent(getEnv("MOVIES_MIGRATION_PERCENT", "50")),
	}
}

func healthHandler(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	w.Header().Set("Content-Type", "text/plain; charset=utf-8")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write([]byte("Strangler Fig Proxy is healthy"))
}

func (c *proxyConfig) handleMovies(w http.ResponseWriter, r *http.Request) {
	target := c.monolithURL
	targetName := "monolith"

	if c.shouldRouteMoviesToMicroservice() {
		target = c.moviesServiceURL
		targetName = "movies-service"
	}

	log.Printf("Routing %s %s to %s", r.Method, r.URL.RequestURI(), targetName)
	c.buildProxy(target).ServeHTTP(w, r)
}

func (c *proxyConfig) proxyTo(target *url.URL) http.HandlerFunc {
	proxy := c.buildProxy(target)
	return func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Proxying %s %s to %s", r.Method, r.URL.RequestURI(), target)
		proxy.ServeHTTP(w, r)
	}
}

func (c *proxyConfig) buildProxy(target *url.URL) *httputil.ReverseProxy {
	return httputil.NewSingleHostReverseProxy(target)
}

func (c *proxyConfig) shouldRouteMoviesToMicroservice() bool {
	if !c.gradualMigration {
		return true
	}

	if c.moviesMigrationPct == 0 {
		return false
	}

	if c.moviesMigrationPct >= 100 {
		return true
	}

	requestNumber := c.moviesRequestCounter.Add(1)
	slot := requestNumber % 100
	return slot < c.moviesMigrationPct
}

func mustParseURL(raw string) *url.URL {
	parsed, err := url.Parse(raw)
	if err != nil {
		log.Fatalf("failed to parse URL %q: %v", raw, err)
	}
	return parsed
}

func getEnv(key, fallback string) string {
	value := os.Getenv(key)
	if value == "" {
		return fallback
	}
	return value
}

func parsePercent(value string) uint64 {
	parsed, err := strconv.Atoi(value)
	if err != nil {
		log.Printf("Invalid MOVIES_MIGRATION_PERCENT=%q, falling back to 50", value)
		return 50
	}

	if parsed < 0 {
		return 0
	}
	if parsed > 100 {
		return 100
	}
	return uint64(parsed)
}
