FROM python:slim-buster
RUN mkdir /opt/app
WORKDIR /opt/app
COPY main.py .
COPY requirements.txt .
RUN pip3 install -r requirements.txt
ENTRYPOINT python3 main.py