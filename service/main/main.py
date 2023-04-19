from flask import Flask

app = Flask(__name__)
metric_values = {
    "400_count": 0,
    "500_count": 0,
    "request_count": 0
}

@app.route("/index")
def index():
    return "hello"

@app.route("/metrics")
def metrics():
    return metric_values

@app.route("/action")
def action():
    metric_values["request_count"] = metric_values["request_count"] + 1
    return "act!"

@app.route("/error_endpoint")
def errored_endpoint():
    return 500

@app.errorhandler(500)
def five_x_handler(e):
    metric_values["500_count"] = metric_values["500_count"] + 1
    return "error"

@app.route("/client_error_endpoint")
def client_errored_endpoint():
    return 400

@app.errorhandler(400)
def four_x_handler(e):
    metric_values["400_count"] = metric_values["400_count"] + 1
    return "client_and_server_is_not_degreed"

if __name__ == "__main__":
    app.run(host="0.0.0.0" , port=8080)
