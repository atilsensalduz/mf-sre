FROM python:slim-buster
LABEL org.opencontainers.image.source="https://github.com/atilsensalduz/mf-sre"

RUN adduser --home /app --system --group appuser
ENV PATH="$PATH:/app/.local/bin"
USER appuser

WORKDIR /app

COPY --chown=appuser:appuser requirements.txt requirements.txt
RUN pip install --user -r requirements.txt

COPY --chown=appuser:appuser main.py .

ENTRYPOINT python3 main.py