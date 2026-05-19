# PostGIS 16 + pgvector — Ergenekon birleşik DB image (3.7.0).
#
# Neden:
#   - Ötüken arazi geometrileri için PostGIS gerekli (mevcut)
#   - Umay AI Faz 2 semantik arama için pgvector gerekli (yeni)
#   - Hazır pgvector image'ları PostGIS içermez → tek başına geçilirse Ötüken bozulur
#
# Çözüm: PostGIS imajının üstüne pgvector kuruyoruz. Postgres major sürümü
# aynı kalıyor (16) → mevcut data volume'u sorunsuz yüklenir, pg_upgrade
# gerekmez.
FROM postgis/postgis:16-3.4

# pgvector — PostgreSQL APT reposu (image'ın temelinde zaten ekli)
RUN apt-get update \
    && apt-get install -y --no-install-recommends postgresql-16-pgvector \
    && rm -rf /var/lib/apt/lists/*
