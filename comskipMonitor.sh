#!/bin/bash

DEFAULT_PROFILE="720CopyAudio"
PLEX_URL="https://plex-server:32400"
TOKEN_FILE="/etc/plex-comskip.token"

source /etc/plex-comskip.conf

SCRIPT_DIR=$(dirname "$BASH_SOURCE")

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -p|--path)
    WORK_DIR="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--start)
    START_HOUR="$2"
    shift # past argument
    shift # past value
    ;;
    -e|--end)
    END_HOUR="$2"
    shift # past argument
    shift # past value
    ;;
    -q|--quality)
    DEFAULT_PROFILE="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--threads)
    THREADS="$2"
    shift
    shift
    ;;
    *)
    shift
    ;;
esac
done

if [[ "${WORK_DIR}" == "" || "${START_HOUR}" == "" || "${END_HOUR}" == "" ]]; then
  echo "Must provide input values for --start, --end, and --path"
  exit
fi

echo "Monitoring ${WORK_DIR} from ${START_HOUR} until ${END_HOUR}"

while [[ "1" == "1" ]]; do
  HOUR=$(date +"%k")
  if [[ "${HOUR}" -gt "${START_HOUR}" && "${HOUR}" -lt "${END_HOUR}" ]]; then
    WORK_FILE=$(ls ${WORK_DIR} | head -1)
    if [[ "${WORK_FILE}" == "" ]]; then
      sleep 300;
    else
      cat "${WORK_DIR}/${WORK_FILE}" | while read REC_FILE; do

        SEARCH_FILE=$(basename "${REC_FILE}")
        SEARCH_PATH=$(dirname "${REC_FILE}" | sed 's/\/\.grab.*//')
        SEARCH_FILE_EXT="${SEARCH_FILE##*.}"
        SEARCH_FILE_NAME="${SEARCH_FILE%.*}"
        ALT_SEARCH_FILE="${SEARCH_FILE_NAME} (copy *).${SEARCH_FILE_EXT}"

        echo "Executing ${WORK_DIR}/${WORK_FILE}... Encoding all files named ${SEARCH_FILE} or ${ALT_SEARCH_FILE} in ${SEARCH_PATH}"

        find "${SEARCH_PATH}" -path "${SEARCH_PATH}/.grab" -prune -o -name "${SEARCH_FILE}" -print -o -name "${ALT_SEARCH_FILE}" -print | while read videoFile; do
          profile=${DEFAULT_PROFILE}
          configFile=""
          thisPath=$(dirname "${videoFile}")
          while [ "${thisPath}" != "/" ] ; do
            if [[ -f "${thisPath}/.plexDvrConfig" ]]; then
              configFile="${thisPath}/.plexDvrConfig"
              break
            fi
            thisPath=$(dirname "${thisPath}")
          done
          if [[ "${configFile}" != "" ]]; then
            configProfile=$(cat "${configFile}" | grep Profile | sed 's/Profile.//')
            configRenameScript=$(cat "${configFile}" | grep RenameScript | sed 's/RenameScript.//')

            if [[ "${configProfile}" != "" ]]; then
              profile=${configProfile}
            fi

            if [[ "${configRenameScript}" != "" ]]; then
              newVideoFile=$(/bin/bash -c "${configRenameScript}" "${videoFile}" "${WORK_FILE}")
              if [[ "${newVideoFile}" != "" ]]; then
                newDir=$(dirname "${newVideoFile}")
                mkdir -p "${newDir}"
                echo "Renaming ${videoFile} to ${newVideoFile}..."
                mv "${videoFile}" "${newVideoFile}"
                videoFile="${newVideoFile}"
              fi
            fi

          fi
          echo "Encoding ${videoFile} with profile ${profile}"
          if [[ "${THREADS}" == "" ]]; then
            ${SCRIPT_DIR}/comskipAndEncode.sh --file "${videoFile}" --profile ${profile} 2>&1
          else
            ${SCRIPT_DIR}/comskipAndEncode.sh --file "${videoFile}" --profile ${profile} --threads ${THREADS} 2>&1
          fi
        done

        TOKEN=$(cat ${TOKEN_FILE})
        LIBRARY=$(curl --silent -k -X GET "${PLEX_URL}/library/sections?X-Plex-Token=${TOKEN}" | grep -o "key=.*type\|Location.*" | grep "key=\|${SEARCH_PATH}" | grep -v unsorted | grep -B 1 Location | grep key | sed 's/key="//;s/" type//');
        echo "Attempting to refresh library ${LIBRARY}"
        curl --silent -k -X GET "${PLEX_URL}/library/sections/${LIBRARY}/refresh?X-Plex-Token=${TOKEN}" 2>&1 > /dev/null 

      done

      rm "${WORK_DIR}/${WORK_FILE}"
    fi
  else
    sleep 300;
  fi
done;
