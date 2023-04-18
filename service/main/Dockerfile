FROM python:slim-buster

RUN adduser --home /app --system --group appuser
ENV PATH="$PATH:/app"
USER appuser

WORKDIR /app

COPY --chown=appuser:appuser requirements.txt requirements.txt
RUN pip install --user -r requirements.txt

COPY --chown=appuser:appuser main.py .

ENTRYPOINT python3 main.py