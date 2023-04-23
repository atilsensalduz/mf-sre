# Exporter Documentation
[![Go Coverage](https://github.com/atilsensalduz/mf-sre/wiki/coverage.svg)](https://raw.githack.com/wiki/atilsensalduz/mf-sre/coverage.html)

## Overview

This application fetches metrics from different services and exposes them as Prometheus metrics. The application uses the `/metrics` endpoint to fetch the metrics data in JSON format. The application periodically fetches the metrics and updates the Prometheus metrics.

## Installation

1. Clone the repository from GitHub:

```
git clone https://github.com/atilsensalduz/mf-sre.git
cd ./service/exporter
```

2. Build the Docker image:

```
docker build -t exporter .
```

## Configuration

To configure the application, create a `.env` file in the root directory of the project and set the `MAIN_APP_URL` variable to the URL of the application whose metrics you want to fetch:

```
MAIN_APP_URL=http://localhost:8080
```

## Usage

To run the application, use the following command:

```
docker run --env-file .env -p 2112:2112 exporter
```

Once the application is running, the metrics can be accessed via the Prometheus endpoint at `http://localhost:2112/metrics`.

## Metrics

The following metrics are available:

- `http_requests_total`: The total number of HTTP requests.
- `http_400_response_total`: The total number of HTTP responses with a status code of 400.
- `http_500_response_total`: The total number of HTTP responses with a status code of 500.

## Endpoints

The following endpoints are available:

- `/metrics`: Returns the Prometheus metrics.

## Troubleshooting

If the application is unable to fetch the metrics, ensure that the `MAIN_APP_URL` variable is set correctly in the `.env` file. If the issue persists, check the logs for any error messages.

## Contributing

If you would like to contribute to this project, please fork the repository and submit a pull request.