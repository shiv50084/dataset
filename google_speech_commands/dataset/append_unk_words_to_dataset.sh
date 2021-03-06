#!/bin/bash

set -e
set -u

readonly DATASET_SOURCE_DIR="${1}/_human_words_"
readonly DATASET_WANTED_DIR=$2
readonly UNKNWN_WORD=$3
readonly WANTED_WORDS=${@:4}

readonly DATASET_TESTING_FILE="${DATASET_SOURCE_DIR}/testing_list.txt"
readonly DATASET_TRAINING_FILE="${DATASET_SOURCE_DIR}/training_list.txt"
readonly DATASET_VALIDATION_FILE="${DATASET_SOURCE_DIR}/validation_list.txt"

# unknown is virtual directory and shouldn't exist in origin dataset

if [ ! -z "`find "${DATASET_WANTED_DIR}" -type d -name "${UNKNWN_WORD}"`" ]; then
  echo "ASSERT: ${UNKNWN_WORD} conflicts with google dataset"
  exit 1
fi

shuf() {
  mawk 'BEGIN {srand(42); OFMT="%.17f"} {print rand(), $0}' \
    | sort -k1,1n | awk '{print $2}'
}

# copy wav samples

copy_unknown_wav_samples() {
  local type=$1
  local txt=$2
  local dest="${DATASET_WANTED_DIR}/${type}/${UNKNWN_WORD}"
  local words=
  local word
  local wav
  local wanted_cnt=${3:-0}

  echo "Copying Unknown Words ${type}..."

  if ((wanted_cnt == 0)); then
    for word in ${WANTED_WORDS} ; do
      wanted_cnt=`find "${DATASET_WANTED_DIR}/${type}/${word}" -type f | wc -l`
      break
    done
  fi

  mkdir "${dest}"

  for word in ${WANTED_WORDS} ; do
    if [ -z "${words}" ]; then
      words=${word}
    else
      words="${words}\|${word}"
    fi
  done

  for wav in `grep -v "^\(${words}\)/" "${txt}" | shuf | head -n "${wanted_cnt}"` ; do
    cp "${DATASET_SOURCE_DIR}/${wav}" "${dest}/${wav%/*}_${wav#*/}"
  done
}

copy_unknown_wav_samples "validation" "${DATASET_VALIDATION_FILE}" 365
copy_unknown_wav_samples "testing" "${DATASET_TESTING_FILE}" 365
copy_unknown_wav_samples "training" "${DATASET_TRAINING_FILE}"

maybe_synthesize_more_unknown_wav_samples() {
  local type=$1
  local dest="${DATASET_WANTED_DIR}/${type}/${UNKNWN_WORD}"
  local dest_cnt=`find "${dest}" -type f | wc -l`
  local word
  local wav
  local wanted_cnt=
  for word in ${WANTED_WORDS} ; do
    wanted_cnt=`find "${DATASET_WANTED_DIR}/${type}/${word}" -type f | wc -l`
    break
  done

  for wav in `find "${dest}" -type f` ; do
    if ((wanted_cnt == dest_cnt)); then
      break
    fi
    ((dest_cnt+=1))
    sox -R "${wav}" "${wav%.*}.norm-10.wav" norm -10
    if ((wanted_cnt == dest_cnt)); then
      break
    fi
    ((dest_cnt+=1))
    sox -R "${wav}" "${wav%.*}.norm-15.wav" norm -15
    if ((wanted_cnt == dest_cnt)); then
      break
    fi
    ((dest_cnt+=1))
    sox -R "${wav}" "${wav%.*}.norm-20.wav" norm -20
  done

  dest_cnt=`find "${dest}" -type f | wc -l`
  if ((wanted_cnt != dest_cnt)); then
    echo "ASSERT: wanted_cnt(${wanted_cnt}) != dest_cnt(${dest_cnt})"
    exit 2
  fi
}

maybe_synthesize_more_unknown_wav_samples "training"
