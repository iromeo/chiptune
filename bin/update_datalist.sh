#!/bin/bash

#
# Functions
#
date_cmd() {
  local arg="${1}"
  if [[ "$(uname)" == 'Darwin' ]]; then
    gdate ${arg}
  elif [[ "$(expr substr $(uname -s) 1 5)" == 'Linux' ]]; then
    date ${arg}
  else
    echo "Your platform ($(uname -a)) is not supported." 2>dev/null
    exit 1
  fi
}

#
# Global variables
#
BASEDIR="$(cd $(dirname ${0}) && pwd -P)"

data_dir="${BASEDIR}/../data/$(date_cmd +%Y%m%d-%H%M)"
mkdir -p "${data_dir}"

bed_dir="${data_dir}/bed"
mkdir -p "${bed_dir}"

#
# Prepare the list of experiments
#

# The original list of processed experiments on the remote FTP server
experimentList_url="http://dbarchive.biosciencedbc.jp/kyushu-u/metadata/experimentList.tab"

# Select ChIP-seq experiments of human TFs
datalist_path="${data_dir}/data.tsv"
curl -s ${experimentList_url} | awk -F'\t' '$2 == "hg19" && $3 == "TFs and others"' > "${datalist_path}"

# The TF experiment ranking
ranking_path="${data_dir}/ranking.txt"
cat "${datalist_path}" | cut -f 4 | sort | uniq -c | sort -nr > "${ranking_path}"

# Top 10 TFs
top10tfs_path="${data_dir}/top10.txt"
head "${ranking_path}" | awk '$0=$2' > "${top10tfs_path}"

# Get each 3 experiment IDs of top 10 TFs
top10_each3expids_path="${data_dir}/top10_each3expids.tsv"
cat "${top10tfs_path}" | while read tf; do
  cat "${datalist_path}" | awk -v tf="${tf}" -F '\t' '$4 == tf' | head -3
done > "${top10_each3expids_path}"

# Get bedfiles of each experiment from NBDC web server
FTP_base="http://dbarchive.biosciencedbc.jp/kyushu-u/hg19/eachData/bed20/"
cat "${top10_each3expids_path}" | while read line; do
  id=$(echo "${line}" | cut -f 1)
  wget -O "${bed_dir}/${id}.bed" "${FTP_base}/${id}.20.bed" 2>/dev/null
done