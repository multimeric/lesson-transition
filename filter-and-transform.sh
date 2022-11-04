#!/usr/bin/env bash
#
# This script transitions a lesson repository to use The Carpentries Workbench
# in two steps:
#
# 1. Use git-filter-repo to create a copy of the lesson and rewrite the git
#    history without boilerplate, styling, or generated content
# 2. Use `transform-lesson.R` to transform the lesson structure from Jekyll to
#    workbench, moving files and rewriting markdown syntax.  
#
# Requirements
#
# 1. A lesson repository in a sub-directory of this lesson (e.g. 
#    swcarpentry/r-novice-gapminder, included as a submodule)
# 2. An R script associated with the repository (e.g. 
#    swcarpentry/r-novice-gapminder.R)
# 3. transform-lesson.R
# 4. dependencies.R
# 5. git-filter-repo (included as a submodule in the directory)
# 6. pat.sh to get github personal access token
# 7. git
#
# Usage
#
# filter-and-transform.sh <out> <post> [paths] [callback]
#
# <out>    a JSON file to contain a record of the commits generated by
#            transform-lesson.R
# <post>   an R script that performs post-transformation cleaning in the format
#            of <user>/<repo>.R 
# [paths]  a file that lists the paths that _should not_ be included in the 
#            workbench repository in the format specified by git-filter-repo:
#            <https://htmlpreview.github.io/?https://github.com/newren/git-filter-repo/blob/docs/html/git-filter-repo.html#_filtering_based_on_many_paths>
#            By default, this is filter-list.txt
# [callback]  a message callback that is used to filter commit messages.
#             (see https://htmlpreview.github.io/?https://github.com/newren/git-filter-repo/blob/docs/html/git-filter-repo.html#CALLBACKS)
#             if this is missing it will evaluate the callback in `message-callback.txt`.
#             To perform no modification, use `"return message"` in this place
#
# Output
#
#  - a transformed lesson in the same path as <out>
#  - a json file (<out>) that records the commit hashes and files associated
#      with those commit hashes
#
# Example
#
# filter-and-transform.sh \
#   sandpaper/carpentries/instructor-training.json \
#   carpentries/instructor-training.R
#
# This will create a transformation of carpentries/instructor-training/ in
# sandpaper/carpentries/instructor-training/ and a record of the commits that
# created the file transformations in
# sandpaper/carpentries/instructor-training.json

# for the makefile, the output is a json file, but we want to make it a directory,
# so we are using parameter expansion
# https://www.gnu.org/software/bash/manual/html_node/Shell-Parameter-Expansion.html
CWD=$(pwd)
OUT=${1%.*} # No file extension
SCRIPT=${2}
FILTER=${3:-${CWD}/filter-list.txt}

REPO="${SCRIPT%.*}" # Repo is script with no file extension
BASE="$(basename ${REPO})"
GHP="$(./pat.sh)"

# Move out the site/ directory in case it has previously been built (keeping the memory alive)
if [[ -d ${OUT}/site/ ]]; then
  mv ${OUT}/site/ ${OUT}../site-${BASE} || echo "" > /dev/null
fi
# removing the directory to make a fresh clone for git-filter-repo
rm -rf ${OUT}
# the clones must be FRESH
git clone --no-local .git/modules/${REPO} ${OUT}

# FILTERING --------------------------------------------------------------------
# 
# This process will filter out the commits that originated from the styles
# repository and contribute nothing to the lesson content. This includes styling
# files AND boilerplate files like LICENSE.md
BLANK=""
CALLBACK=${4:-$(eval echo $(cat ${CWD}/message-callback.txt))}
echo -e "\033[1mConverting \033[38;5;208m${OUT}\033[0;00m...\033[22m"
cd ${OUT}
git-filter-repo \
  --prune-empty=always \
  --invert-paths \
  --paths-from-file ${FILTER} \
  --message-callback "${CALLBACK}"

# Update our branch and remote
ORIGIN=https://github.com/fishtree-attempt/${BASE}.git
CURRENT_BRANCH=$(git branch --show-current)
echo -e "\033[1mSetting origin to \033[38;5;208m${ORIGIN}\033[0;00m...\033[22m"
if [[ $(git remote -v) ]]; then
  git remote set-url origin ${ORIGIN}
else
  git remote add origin ${ORIGIN}
fi
if [[ ${CURRENT_BRANCH} != 'main' ]]; then 
  echo -e "\033[1mSetting default branch from \033[38;5;208m${CURRENT_BRANCH}\033[0;00m to \033[38;5;208mmain\033[0;00m...\033[22m"
fi
git branch -m main

# Back to our home and move the site back where it belongs
cd ${CWD}
if [[ -d ${OUT}../site-${BASE} ]]; then
  mv ${OUT}../site-${BASE} ${OUT}site/ || echo "" > /dev/null
fi

echo -e "... \033[1m\033[38;5;208mdone\033[0;00m\033[22m"

# R Ecology Lesson was not built the same way as other Carpentries lessons, so
# it runs through its own script.
if [[ ${SCRIPT} == 'datacarpentry/R-ecology-lesson.R' ]]; then
  GITHUB_PAT="${GHP}" Rscript ${SCRIPT} \
    --build \
    --funs functions.R \
    --template template/ \
    --output ${OUT} \
    ${REPO} 
else
  GITHUB_PAT="${GHP}" Rscript transform-lesson.R \
    --build \
    --fix-liquid \
    --funs functions.R \
    --template template/ \
    --output ${OUT} \
    ${REPO} \
    ${SCRIPT}
fi

