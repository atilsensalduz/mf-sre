FROM python:slim-buster

RUN adduser --disabled-login appuser
USER appuser
WORKDIR /home/appuser

COPY --chown=appuser:appuser requirements.txt requirements.txt
RUN pip install --user -r requirements.txt

ENV PATH=/home/appuser/.local/bin:$PATH

COPY --chown=appuser:appuser . .

ENTRYPOINT python3 main.py