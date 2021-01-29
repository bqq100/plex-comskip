#!/bin/bash

#####################################
#
# Temporary directory for storing
#   files during processing
#
#####################################
TMP_DIR="/tmp/"
DELETE_ORIG="true"
ALLOW_REPLACE="false"
COMSKIP="true"
SUBTITLES="true"

source /etc/plex-comskip.conf

while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -t|--tmp)
    TMP_DIR="$2"
    shift # past argument
    shift # past value
    ;;
    -f|--file)
    FILE="$2"
    shift # past argument
    shift # past value
    ;;
    -p|--profile)
    PROFILE="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--threads)
    THREADS="$2"
    shift
    shift
    ;;
    -k|--keep)
    if [[ "${ALLOW_REPLACE}" == "true" ]]; then
      echo "ERROR: Cannot specify both --keep and --replace"
      exit
    fi
    DELETE_ORIG="false"
    shift
    ;;
    -r|--replace)
    if [[ "${DELETE_ORIG}" == "false" ]]; then
      echo "ERROR: Cannot specify both --keep and --replace"
      exit
    fi
    ALLOW_REPLACE="true"
    shift
    ;;
    --no-comskip)
    COMSKIP="false"
    shift
    ;;
    --no-subtitles)
    SUBTITLES="false"
    shift
    ;;
    -h|--help)
    echo "Options: --tmp, --file, --profile, --threads, --keep, --no-comskip, --no-subtitles"
    exit
    ;;
    *)
    shift
    ;;
esac
done

#####################################
#
# Setup variables
#
#####################################
FILENAME=$(basename "${FILE}")
CUR_EXTENSION="${FILENAME##*.}"
NEW_EXTENSION="mp4"
if [[ "${DELETE_ORIG}" == "false" ]]; then
  if [[ "${CUR_EXTENSION}" == "mp4" ]]; then
     NEW_EXTENSION="m4v"
  fi
fi
CUR_EXTENSION="${FILENAME##*.}"
NEW_FILENAME="${FILENAME%.*}.${NEW_EXTENSION}"
INIT_DIR=${TMP_DIR}${FILENAME}
TARG_DIR=$(dirname "${FILE}")
BIN_DIR=$(dirname "$BASH_SOURCE")/bin

#####################################
#
# Check the source file valid and exists
#
#####################################
if [[ ! "${FILE}" ]]; then
  echo "File is a required parameter... Exiting..."
  exit 1
fi
if [[ ! -f "${FILE}" ]]; then
  echo "Could not find ${FILE}... Exiting..."
  exit 1
fi

#####################################
#
# Check if the file already exists
#
#####################################
if [[ "${ALLOW_REPLACE}" == "false" ]]; then
  if [ -f "${TARG_DIR}/${NEW_FILENAME}" ]; then
    echo "${TARG_DIR}/${NEW_FILENAME} already exists... Exiting..."
    exit 1
  fi
fi

#####################################
#
# Create directory for temp files
#
#####################################
if [ -d "${INIT_DIR}" ]; then
  TIMESTAMP=$(date +"%Y%m%d%H%M%S")
  echo "${INIT_DIR} already exists... moving contents to ${INIT_DIR}/${TIMESTAMP}"
  mkdir -p "${INIT_DIR}/${TIMESTAMP}"
  mv "${INIT_DIR}"/* "${INIT_DIR}/${TIMESTAMP}"
fi
mkdir -p "${INIT_DIR}/tmp"

#####################################
#
# Default High Quality encoding
#
#####################################
VBITRATE=8000
ABITRATE=0
VHEIGHT=0
VPROFILE="high"
VLEVEL="4.0"
PRESET="medium" #ultrafast, superfast, veryfast, faster, fast, medium, slow, slower, veryslow
MODE="crf"
CRF="18"
ACODEC="copy"

#####################################
#
# Preset encoding settings
#
#####################################
if [[ "${PROFILE}" == "quick720" ]]; then
  VBITRATE=3000
  ABITRATE=128
  VHEIGHT=720
  VPROFILE="main"
  VLEVEL="4.0"
  PRESET="superfast"
  MODE="crf"
  CRF="23"
  ACODEC="aac"
fi
if [[ "${PROFILE}" == "quick720CopyAudio" ]]; then
  VBITRATE=3000
  ABITRATE=0
  VHEIGHT=720
  VPROFILE="main"
  VLEVEL="4.0"
  PRESET="superfast"
  MODE="crf"
  CRF="23"
  ACODEC="copy"
fi
if [[ "${PROFILE}" == "720" ]]; then
  VBITRATE=5000
  ABITRATE=128
  VHEIGHT=720
  VPROFILE="main"
  VLEVEL="4.0"
  PRESET="faster"
  MODE="crf"
  CRF="18"
  ACODEC="aac"
fi
if [[ "${PROFILE}" == "720CopyAudio" ]]; then
  VBITRATE=5000
  ABITRATE=0
  VHEIGHT=720
  VPROFILE="main"
  VLEVEL="4.0"
  PRESET="faster"
  MODE="crf"
  CRF="18"
  ACODEC="copy"
fi
if [[ "${PROFILE}" == "low720" ]]; then
  VBITRATE=2000
  ABITRATE=128
  VHEIGHT=720
  VPROFILE="main"
  VLEVEL="4.0"
  PRESET="faster"
  MODE="crf"
  CRF="25"
  ACODEC="aac"
fi
if [[ "${PROFILE}" == "low720CopyAudio" ]]; then
  VBITRATE=2000
  ABITRATE=0
  VHEIGHT=720
  VPROFILE="main"
  VLEVEL="4.0"
  PRESET="faster"
  MODE="crf"
  CRF="25"
  ACODEC="copy"
fi
if [[ "${PROFILE}" == "copy" ]]; then
  VBITRATE=0
  ABITRATE=0
  VHEIGHT=0
  VPROFILE="main"
  VLEVEL="4.0"
  PRESET="medium"
  MODE="copy"
  CRF="0"
  ACODEC="copy"
fi

######################################
#
# Find commercials, build mp4 metadata
#   and copy comskip results for other
#   programs (ie Kodi)
#
######################################
echo ";FFMETADATA1" > "${INIT_DIR}/chapters.meta"
if [[ "${COMSKIP}" == "true" ]]; then
  TITLE=$(echo "${NEW_FILENAME}" | sed 's/.*\ -\ //;s/.mp4//;s/.m4v//');
  if [[ "${TITLE}" != "" ]]; then
    echo "title=${TITLE}" >> "${INIT_DIR}/chapters.meta"
  fi
  ${BIN_DIR}/comskip "${FILE}" --output="${INIT_DIR}"
  $(cat "${INIT_DIR}"/*.xml | grep start | sed 's/\s*<commercial\s//;s/\s\/>//;s/\s/\n/;s/start=//;s/end=//;s/"//g' | awk 'BEGIN{start=0;end=0;cnt=0;} //{start=end;end=$1;print "[CHAPTER]";print "TIMEBASE=1/10000000";printf("START=%d\n",start*10000000);printf("END=%d\n",end*10000000);if(cnt%2==0){print "title=Show"}else{print"title=Commercial"};cnt=cnt+1}' >> "${INIT_DIR}/chapters.meta")
fi

#####################################
#
# Handle Closed Captions
#
#####################################
if [[ "${SUBTITLES}" == "true" ]]; then
  ESCAPED_FILE=${FILE//;/\\;}
  SUB_STREAM=$(${BIN_DIR}/ffprobe -f lavfi -i movie="${ESCAPED_FILE}[out+subcc]" 2>&1 | grep Subtitle | grep -o "#.:." | sed 's/#//')
  if [[ "${SUB_STREAM}" != "" ]];then
    SUB_FILENAME="${FILENAME%.*}.srt"
    ${BIN_DIR}/ffmpeg -nostdin -f lavfi -i movie="${ESCAPED_FILE}[out+subcc]" -map 0:1 "${INIT_DIR}/${SUB_FILENAME}"
  fi
fi

#####################################
#
# Build ffmpeg arguments
#
#####################################
if [[ "${THREADS}" == "" ]]; then
  THREAD_ARGS=""
else
  THREAD_ARGS="-threads ${THREADS}"
fi

if [[ "${MODE}" == "copy" ]]; then
  STD_ARGS="-map_metadata 1 -c:v copy -c:a copy"
  AF_SWITCH=""
  AUD_FILTERS=""
  VID_FILTERS=""
  VID_ARGS=""
else
  STD_ARGS="-map_metadata 1 -preset ${PRESET} -c:v libx264 -profile:v ${VPROFILE}"
fi

if [[ "${MODE}" != "copy" ]]; then
  if [[ "${ACODEC}" == "copy" ]]; then
    AUD_ARGS="-c:a copy"
    AF_SWITCH=""
    AUD_FILTERS=""
  else
    AUD_ARGS="-c:a ${ACODEC} -b:a ${ABITRATE}k -ac 2"
    AF_SWITCH="-af"
    AUD_FILTERS="pan='stereo|FL<1.0*FL+0.707*FC+0.707*BL|FR<1.0*FR+0.707*FC+0.707*BR'"
  fi

  VF_SWITCH="-vf"
  if [[ "${VHEIGHT}" -gt 0 ]]; then
    VID_FILTERS="yadif,scale='-1':'min(${VHEIGHT},ih)'"
  else
    VID_FILTERS="yadif"
  fi

  if [[ "${MODE}" == "crf" ]]; then
    if [[ "${VBITRATE}" -gt 0 ]]; then
      VID_ARGS="-crf ${CRF} -maxrate ${VBITRATE}k -bufsize 2M"
    else
      VID_ARGS="-crf ${CRF}"
    fi
  else
    VID_ARGS="-b:v ${VBITRATE}k"
  fi
fi

#####################################
#
# Run ffmpeg to convert and add
#  chapters
#
#####################################
if [[ "${MODE}" == "two" ]]; then
  ${BIN_DIR}/ffmpeg -y -nostdin -i "${FILE}" -i "${INIT_DIR}/chapters.meta" ${STD_ARGS} ${VID_ARGS} ${VF_SWITCH} ${VID_FILTERS} \
       ${AUD_ARGS} ${AF_SWITCH} ${AUD_FILTERS} -f mp4 -pass 1 -passlogfile "${INIT_DIR}/plog" ${THREAD_ARGS} /dev/null
  ${BIN_DIR}/ffmpeg -nostdin -i "${FILE}" -i "${INIT_DIR}/chapters.meta" ${STD_ARGS} ${VID_ARGS} ${VF_SWITCH} ${VID_FILTERS} \
       ${AUD_ARGS} ${AF_SWITCH} ${AUD_FILTERS} -pass 2 -passlogfile "${INIT_DIR}/plog" ${THREAD_ARGS} "${INIT_DIR}/${NEW_FILENAME}"
fi

if [[ "${MODE}" == "one" || "${MODE}" == "crf" || "${MODE}" == "copy" ]]; then
  ${BIN_DIR}/ffmpeg -nostdin -i "${FILE}" -i "${INIT_DIR}/chapters.meta" ${STD_ARGS} ${VID_ARGS} ${VF_SWITCH} ${VID_FILTERS} \
       ${AUD_ARGS} ${AF_SWITCH} ${AUD_FILTERS} ${THREAD_ARGS} "${INIT_DIR}/${NEW_FILENAME}"
fi

####################################
#
# Cleanup
#
####################################

ORIG_SIZE=$(${BIN_DIR}/ffmpeg -nostdin -i "${FILE}" 2>&1 | grep "Duration" | grep bitrate | cut -d ' ' -f 4 | sed s/,// | sed 's@\..*@@g' | awk '{ split($1, A, ":"); split(A[3], B, "."); print 3600*A[1] + 60*A[2] + B[1] }')
NEW_SIZE=$(${BIN_DIR}/ffmpeg -nostdin -i "${INIT_DIR}/${NEW_FILENAME}" 2>&1 | grep "Duration" | grep bitrate | cut -d ' ' -f 4 | sed s/,// | sed 's@\..*@@g' | awk '{ split($1, A, ":"); split(A[3], B, "."); print 3600*A[1] + 60*A[2] + B[1] }')
SIZE_DIFF=$(((${ORIG_SIZE}-${NEW_SIZE})*(${ORIG_SIZE}-${NEW_SIZE})))

if [[ "${SIZE_DIFF}" == "0" || "${SIZE_DIFF}" == "1" ]]; then

  cp -f "${INIT_DIR}/${NEW_FILENAME}" "${TARG_DIR}"
  cp -f "${INIT_DIR}"/*.srt "${TARG_DIR}"
  cp -f "${INIT_DIR}"/*.txt "${TARG_DIR}"
  COPY_SIZE=$(${BIN_DIR}/ffmpeg -nostdin -i "${TARG_DIR}/${NEW_FILENAME}" 2>&1 | grep "Duration" | grep bitrate | cut -d ' ' -f 4 | sed s/,// | sed 's@\..*@@g' | awk '{ split($1, A, ":"); split(A[3], B, "."); print 3600*A[1] + 60*A[2] + B[1] }')

  if [[ "${NEW_SIZE}" == "${COPY_SIZE}" ]]; then
    rm -Rf "${INIT_DIR}"
    if [[ "${ALLOW_REPLACE}" == "false" ]]; then
      if [[ "${DELETE_ORIG}" == "true" ]]; then
        rm -f "${FILE}"
      fi
    fi
  else
    if [[ "${ALLOW_REPLACE}" == "false" ]]; then
      echo "Failed to copy ${NEW_FILENAME} to its final location (${TARG_DIR})."
    else
      echo "Failed to replace ${NEW_FILENAME} at ${TARG_DIR} with it's new encoded version.  Data may have been lost!"
    fi
    exit 1
  fi

else
  echo "Encoding failed... Original length was ${ORIG_SIZE}, but the new length is ${NEW_SIZE}."
  exit 1
fi
