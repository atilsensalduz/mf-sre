package main

import (
	"io/ioutil"
	"net/http"
	"net/http/httptest"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
)

func TestGetMetric(t *testing.T) {
	// Set up a test HTTP server
	server := httptest.NewServer(http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		rw.Write([]byte(`{"400_count": 10, "500_count": 5, "request_count": 100}`))
	}))
	defer server.Close()

	// Set the MAIN_APP_URL environment variable to the test server's URL
	os.Setenv("MAIN_APP_URL", server.URL)

	// Call getMetric to retrieve the metrics from the test server
	m, err := getMetrics(os.Getenv("MAIN_APP_URL"))
	if err != nil {
		t.Errorf("getMetric returned an error: %v", err)
	}

	// Verify that the retrieved metrics match the expected values
	if m.Four00Count != 10 {
		t.Errorf("Expected Four00Count to be %d but got %d", 10, m.Four00Count)
	}
	if m.Five00Count != 5 {
		t.Errorf("Expected Five00Count to be %d but got %d", 5, m.Five00Count)
	}
	if m.RequestCount != 100 {
		t.Errorf("Expected RequestCount to be %d but got %d", 100, m.RequestCount)
	}
}

func TestRecordMetrics(t *testing.T) {
	// Set up a test HTTP server that returns a fixed set of metrics
	server := httptest.NewServer(http.HandlerFunc(func(rw http.ResponseWriter, req *http.Request) {
		rw.Write([]byte(`{"400_count": 10, "500_count": 5, "request_count": 100}`))
	}))
	defer server.Close()

	// Set the MAIN_APP_URL environment variable to the test server's URL
	os.Setenv("MAIN_APP_URL", server.URL)

	// Start recording metrics in a separate goroutine
	go recordMetrics()

	// Wait for a short time to allow metrics to be retrieved and recorded
	// a few times
	waitTime := 5 * time.Second
	time.Sleep(waitTime)

	app := httptest.NewServer(promhttp.Handler())
	defer app.Close()

	// Retrieve the recorded metrics from Prometheus
	resp, err := http.Get(app.URL)
	if err != nil {
		t.Errorf("Failed to retrieve metrics: %v", err)
	}
	defer resp.Body.Close()

	// Verify that the metrics were recorded correctly
	body, err := ioutil.ReadAll(resp.Body)
	if err != nil {
		t.Errorf("Error reading response body: %v", err)
	}
	if !strings.Contains(string(body), "http_requests_total") {
		t.Errorf("Expected response body to contain http_requests_total but got: %s", body)
	}
	if !strings.Contains(string(body), "http_400_response_total") {
		t.Errorf("Expected response body to contain http_400_response_total but got: %s", body)
	}
	if !strings.Contains(string(body), "http_500_response_total") {
		t.Errorf("Expected response body to contain http_500_response_total but got: %s", body)
	}
}
