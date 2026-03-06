FROM python:3.11-slim

ARG DOCKER_IMAGE_VERSION=unknown
ENV DOCKER_IMAGE_VERSION=${DOCKER_IMAGE_VERSION}

WORKDIR /app
COPY . /app/

RUN pip install --no-cache-dir -r requirements.txt

EXPOSE 5000
ENV FLASK_APP=app.py
CMD ["python", "-m", "flask", "run", "--host", "0.0.0.0", "--port", "5000"]
