#!/bin/bash

set -euo pipefail

BACKUP_DIR="/opt/backups/$(date +%Y%m%d_%H%M%S)"
LOG_FILE="/var/log/besu_backup.log"

echo "$(date '+[%Y-%m-%d %H:%M:%S]') 🔄 백업 시작..." | tee -a $LOG_FILE

mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname $LOG_FILE)"

# Genesis 파일 백업
echo "$(date '+[%Y-%m-%d %H:%M:%S]') 📋 Genesis 파일 백업..." | tee -a $LOG_FILE
if [ -f /opt/ibft/genesis.json ]; then
  cp /opt/ibft/genesis.json "$BACKUP_DIR/" 2>/dev/null && \
  echo "$(date '+[%Y-%m-%d %H:%M:%S]') ✅ Genesis 백업 완료" | tee -a $LOG_FILE
else
  echo "$(date '+[%Y-%m-%d %H:%M:%S]') ⚠️ Genesis 파일 미발견" | tee -a $LOG_FILE
fi

# Validator 키 백업
echo "$(date '+[%Y-%m-%d %H:%M:%S]') 🔑 Validator 키 백업..." | tee -a $LOG_FILE
if [ -d /opt/ibft/config/keys ]; then
  tar -czf "$BACKUP_DIR/validator_keys.tar.gz" /opt/ibft/config/keys/ 2>/dev/null && \
  echo "$(date '+[%Y-%m-%d %H:%M:%S]') ✅ 키 백업 완료" | tee -a $LOG_FILE
else
  echo "$(date '+[%Y-%m-%d %H:%M:%S]') ⚠️ Validator 키 미발견" | tee -a $LOG_FILE
fi

# 배포 스크립트 백업
echo "$(date '+[%Y-%m-%d %H:%M:%S]') 📜 배포 스크립트 백업..." | tee -a $LOG_FILE
if [ -d ~/sh ]; then
  tar -czf "$BACKUP_DIR/scripts.tar.gz" ~/sh/ 2>/dev/null && \
  echo "$(date '+[%Y-%m-%d %H:%M:%S]') ✅ 스크립트 백업 완료" | tee -a $LOG_FILE
fi

# 오래된 백업 정리 (7일 이상)
find /opt/backups -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true

echo "$(date '+[%Y-%m-%d %H:%M:%S]') ✅ 백업 완료!" | tee -a $LOG_FILE
