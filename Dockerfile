FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    STREAMLIT_SERVER_HEADLESS=true \
    STREAMLIT_BROWSER_GATHER_USAGE_STATS=false

WORKDIR /app

# git: dbt deps lo usa para resolver paquetes.
RUN apt-get update && apt-get install -y --no-install-recommends git \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY dbt/ dbt/
RUN cd dbt && dbt deps

COPY app/ app/
COPY queries/ queries/

# data/ se monta como volumen: ecommerce.duckdb entra y warehouse.duckdb sale al host.
WORKDIR /app/dbt
