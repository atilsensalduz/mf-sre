package main

import (
	"encoding/json"
	"errors"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

// Define a struct to hold the metrics we retrieve from the external service
type metrics struct {
	Four00Count  int `json:"400_count"`
	Five00Count  int `json:"500_count"`
	RequestCount int `json:"request_count"`
}

// Define a client with a custom timeout
var client = &http.Client{Timeout: 5 * time.Second}

// Function to retrieve the metrics from the external service
func getMetrics(url string) (metrics, error) {
	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return metrics{}, errors.New("failed to create GET request")
	}

	res, err := client.Do(req)
	if err != nil {
		return metrics{}, errors.New("failed to send GET request")
	}
	defer res.Body.Close()

	if res.StatusCode != http.StatusOK {
		return metrics{}, fmt.Errorf("invalid response status code %d", res.StatusCode)
	}

	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		return metrics{}, errors.New("failed to read response body")
	}

	var m metrics
	if err := json.Unmarshal(body, &m); err != nil {
		return metrics{}, errors.New("failed to unmarshal response body")
	}

	return m, nil
}

// Function to periodically retrieve metrics and update Prometheus metrics
func recordMetrics() {
	for {
		// Get the metrics from the external service
		m, err := getMetrics(os.Getenv("MAIN_APP_URL") + "/metrics")
		if err != nil {
			// If there was an error getting the metrics, print the error and wait for 2 seconds before trying again
			fmt.Println(err)
			time.Sleep(2 * time.Second)
			continue
		}

		// Update the Prometheus metrics with the retrieved metrics
		RequestCountMetric.Set(float64(m.RequestCount))
		Four00CountMetric.Set(float64(m.Four00Count))
		Five00CountMetric.Set(float64(m.Five00Count))

		// Wait for 2 seconds before retrieving metrics again
		time.Sleep(2 * time.Second)
	}
}

// Define Prometheus metrics
var RequestCountMetric = promauto.NewGauge(
	prometheus.GaugeOpts{
		Name: "http_requests_total",
		Help: "The total number of http requests",
	},
)

var Four00CountMetric = promauto.NewGauge(
	prometheus.GaugeOpts{
		Name: "http_400_response_total",
		Help: "The total number of http response code 400",
	},
)

var Five00CountMetric = promauto.NewGauge(
	prometheus.GaugeOpts{
		Name: "http_500_response_total",
		Help: "The total number of http response code 500",
	},
)

func main() {
	// Start a goroutine to periodically retrieve metrics and update Prometheus metrics
	go recordMetrics()

	// Expose the Prometheus metrics via an HTTP endpoint
	http.Handle("/metrics", promhttp.Handler())
	if err := http.ListenAndServe(":2112", nil); err != nil {
		panic(err)
	}
}
