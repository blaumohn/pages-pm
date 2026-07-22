# Nur für Tests: PostgreSQL 18 + pgTAP.
# Getrennt vom Produktionsabbild postgres:18 in compose.yaml, damit pgTAP und
# der TAP-Testläufer nur in der Testumgebung verfügbar sind.
FROM postgres:18

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        postgresql-18-pgtap \
        libtap-parser-sourcehandler-pgtap-perl \
    && rm -rf /var/lib/apt/lists/*
