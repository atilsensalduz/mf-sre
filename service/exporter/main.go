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

type metrics struct {
	Four00Count  int `json:"400_count"`
	Five00Count  int `json:"500_count"`
	RequestCount int `json:"request_count"`
}

func getMetric() (metrics, error) {
	url := os.Getenv("MAIN_APP_URL") + "/metrics"

	req, err := http.NewRequest("GET", url, nil)
	if err != nil {
		return metrics{}, errors.New("error in GET request")
	}

	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return metrics{}, err
	}
	defer res.Body.Close()

	body, err := ioutil.ReadAll(res.Body)
	if err != nil {
		return metrics{}, errors.New("error reading response")
	}

	var m metrics
	if err := json.Unmarshal(body, &m); err != nil {
		return metrics{}, errors.New("error unmarshaling JSON")
	}

	return m, nil
}

func recordMetrics() {
	for {
		m, err := getMetric()
		if err != nil {
			fmt.Println(err)
			time.Sleep(2 * time.Second)
			continue
		}

		RequestCountMetric.Set(float64(m.RequestCount))
		Four00CountMetric.Set(float64(m.Four00Count))
		Five00CountMetric.Set(float64(m.Five00Count))

		time.Sleep(2 * time.Second)
	}
}

var RequestCountMetric = promauto.NewGauge(
	prometheus.GaugeOpts{
		Name: "http_requests_total",
		Help: "The total number of http request",
	},
)

var Four00CountMetric = promauto.NewGauge(
	prometheus.GaugeOpts{
		Name: "http_400_response_total",
		Help: "The total number of http 400 response",
	},
)

var Five00CountMetric = promauto.NewGauge(
	prometheus.GaugeOpts{
		Name: "http_500_response_total",
		Help: "The total number of http 500 response",
	},
)

func main() {
	go recordMetrics()

	http.Handle("/metrics", promhttp.Handler())
	http.ListenAndServe(":2112", nil)
}
