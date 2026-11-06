FROM python:3.12-slim
RUN apt-get update && apt-get install -y --no-install-recommends python3 sudo qrencode passwd && rm -rf /var/lib/apt/lists/*
COPY . /opt/plugin
RUN useradd -m -s /bin/bash access-test
CMD ["python3", "-B", "/opt/plugin/tests/integration.py"]
