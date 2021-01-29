#!/bin/bash

TMP_DIR="/tmp/"
COMSKIP_REMOTE_PATH="/mnt/comskip/"

source /etc/plex-comskip.conf

LOCKFILE="/tmp/`basename $0`"
BIN_DIR=$(dirname "$BASH_SOURCE")/bin

if [[ -e "${LOCKFILE}" ]]; then
    PID=$(cat "${LOCKFILE}")
    PID_CNT=$(ps ${PID} | wc -l) 
    if [[ "${PID_CNT}" -gt "1" ]]; then
        exit
    fi
fi

echo $$ > "${LOCKFILE}"

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    *)
    SEARCH_PATH="$1"
    ##################################
    #
    # Cleanup Comskip files that no 
    # longer have a video file
    #
    ##################################
    find "${SEARCH_PATH}" -name "*.txt" -print | while read COMSKIP_FILE; do
        FILE_NO_EXT=${COMSKIP_FILE%.txt}
        COUNT=$(ls "${FILE_NO_EXT}"* | grep -v srt | grep -v txt | wc -l)
        if [[ "${COUNT}" -lt 1 ]]; then
            echo "Cleaning up ${COMSKIP_FILE}"
            rm -f "${COMSKIP_FILE}"
        fi
    done

    ##################################
    #
    # Cleanup Subtitle files that no 
    # longer have a video file
    #
    ##################################
    find "${SEARCH_PATH}" -name "*.srt" -print | while read SUBTITLE_FILE; do
        FILE_NO_EXT=${SUBTITLE_FILE%.srt}
        COUNT=$(ls "${FILE_NO_EXT}"* | grep -v srt | grep -v txt | wc -l)
        if [[ "${COUNT}" -lt 1 ]]; then
            echo "Cleaning up ${SUBTITLE_FILE}"
            rm -f "${SUBTITLE_FILE}"
        fi
    done

    ##################################
    #
    # Find or Create Comskip files
    # for any wtv files that do not
    # have one 
    #
    ##################################
    find "${SEARCH_PATH}" -name "*.wtv" -print | while read VIDEO_FILE; do
        if [[ "${VIDEO_FILE}" != *"(P)"* ]];then
            VIDEO_FILENAME=$(basename "${VIDEO_FILE}")
            COMSKIP_FILE="${VIDEO_FILE%.wtv}.txt"
            COMSKIP_FILENAME=$(basename "${COMSKIP_FILE}")
            COMSKIP_REMOTE_FILE="${COMSKIP_REMOTE_PATH}${COMSKIP_FILENAME}"
            if [ ! -e "${COMSKIP_FILE}" ]; then
                if [[ -e "${COMSKIP_REMOTE_FILE}" ]]; then
                    echo "Found ${COMSKIP_REMOTE_FILE} for ${VIDEO_FILE}"
                    cp "${COMSKIP_REMOTE_FILE}" "${COMSKIP_FILE}"
                else
                    echo "Could not find comskip file for ${VIDEO_FILE}"
                    FS=$(df -P -T "${VIDEO_FILE}" | tail -n +2 | awk '{print $2}')
                    if [[ "${FS}" != "cifs" && "${FS}" != "nfs" ]]; then
                        echo "Video file is local.  Running Comskip..."

                        INIT_DIR=${TMP_DIR}${VIDEO_FILENAME}
                        if [ -d "${INIT_DIR}" ]; then
                            TIMESTAMP=$(date +"%Y%m%d%H%M%S")
                            echo "${INIT_DIR} already exists... moving contents to ${INIT_DIR}/${TIMESTAMP}"
                            mkdir -p "${INIT_DIR}/${TIMESTAMP}"
                            mv "${INIT_DIR}"/* "${INIT_DIR}/${TIMESTAMP}"
                        fi

                        mkdir -p "${INIT_DIR}"
                        ${BIN_DIR}/comskip "${VIDEO_FILE}" --output="${INIT_DIR}"
                        cp "${INIT_DIR}"/*.txt "${COMSKIP_FILE}"
                        rm -Rf "${INIT_DIR}"
                    fi
                fi
            fi
        fi 
    done
    shift
    ;;
esac
done
