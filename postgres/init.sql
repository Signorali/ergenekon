-- Ergenekon PostgreSQL Başlangıç Scripti
-- PostgreSQL ilk başlatıldığında yalnızca POSTGRES_DB değişkenindeki
-- veritabanını oluşturur. Umay ve Ötüken için "umay" DB ayrıca gereklidir.

SELECT 'CREATE DATABASE umay'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'umay')
\gexec
