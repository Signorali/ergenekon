#!/bin/bash
# PostgreSQL Backup Script - Production Ready
# Scheduled backup with retention policy
# Usage: ./backup-postgres.sh

set -e

BACKUP_DIR="/var/lib/postgresql/backups"
DB_NAME="${DB_NAME:-ergenekon}"
DB_USER="${DB_USER:-postgres}"
RETENTION_DAYS=7
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/ergenekon_backup_${TIMESTAMP}.sql.gz"

echo "=================================================="
echo "🔄 PostgreSQL Backup Started: $(date)"
echo "=================================================="
echo "Database: $DB_NAME"
echo "Backup File: $BACKUP_FILE"
echo ""

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Perform backup
echo "📦 Creating backup..."
pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"
BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)

echo "✅ Backup completed: $BACKUP_SIZE"
echo ""

# Cleanup old backups (retention policy)
echo "🧹 Cleaning up old backups (keeping last $RETENTION_DAYS days)..."
CLEANUP_DATE=$(date -d "$RETENTION_DAYS days ago" +"%Y%m%d")

find "$BACKUP_DIR" -name "ergenekon_backup_*.sql.gz" -type f | while read old_backup; do
    BACKUP_DATE=$(basename "$old_backup" | sed 's/ergenekon_backup_//g' | sed 's/_.*//')
    if [ "$BACKUP_DATE" -lt "$CLEANUP_DATE" ]; then
        rm -v "$old_backup"
        echo "🗑️ Deleted: $(basename $old_backup)"
    fi
done

echo ""
echo "=================================================="
echo "✅ Backup completed successfully!"
echo "📍 Location: $BACKUP_FILE"
echo "📊 Size: $BACKUP_SIZE"
echo "=================================================="
