#!/bin/bash

#####################################
#
# Temporary directory for storing
#   files during processing
#
#####################################
WORK_DIR="/tmp/work"
REGEX="^/tv/movies.*"

source /etc/plex-comskip.conf

TIMESTAMP=$(date +"%Y%m%d%H%M%S")
FILENAME=$(basename "${1}")
WORK_FILENAME="${TIMESTAMP}-${FILENAME}"

if [[ "${1}" =~ ${REGEX} ]]; then
  echo "${1}" > "${WORK_DIR}.1/${WORK_FILENAME}"
else
  echo "${1}" > "${WORK_DIR}/${WORK_FILENAME}"
fi
