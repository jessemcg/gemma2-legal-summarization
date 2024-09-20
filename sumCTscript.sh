#!/bin/bash

# make functions stored in a separate file available
source ./functions.sh

# initialize input variables
file_path=""

# initialize input variables
csplit_var=""
file_path=""

# Parse command-line options
while getopts "f:s:" opt; do
  case $opt in
    f)
      file_path="$OPTARG"
	  # all only file name as input if in correct directory
	  if [[ "$file_path" != /* ]]; then
	    file_path="$(pwd)/$file_path"
      fi
      ;;
    s)
      csplit_var="$OPTARG"
      ;;
    *)
      echo "Usage: $0 -f <input_file> -s <csplit_variable>"
      exit 1
      ;;
  esac
done

# Check if required options are provided
if [ -z "$file_path" ] || [ -z "$csplit_var" ]; then
  echo "Error: Input file and csplit variable are required."
  echo "Usage: $0 -f <input_file> -s <csplit_variable>"
  exit 1
fi

# create the variable for splitting up the text file
split="$csplit_var"

# start gemma-2 27b server
cd $HOME/llama.cpp
./llama-server -m models/gemma-2-27b-it-Q4_K_L.gguf -ngl 999 --port 8081 &
sleep 5

# other variables
TEMP_ENV="/dev/shm/SummarizeCT"
RAW_TEXT="${TEMP_ENV}/raw_text.txt"
SUMMARY="${TEMP_ENV}/CTsummary.md"
PROJ_HOME="$HOME/gemma2-legal-summarization"
markdown_css="$PROJ_HOME/markdown.css"

# create temp environment
create_temp_environment "$TEMP_ENV"

# go to temp invironment
cd "$TEMP_ENV"

# copy raw text file to temp invironment
cp "$file_path" "$RAW_TEXT"

# optional text processing on text file
convert_to_ascii "$RAW_TEXT"                            # convert to ASCII to get rid of random characters
sed -i 's/\\//g' "$RAW_TEXT"                            # remove preexisting backslashes
sed -i -e 's/"/\\"/g' "$RAW_TEXT"                       # insert backslash before quote
sed -i -e "s/'/\\'/g" "$RAW_TEXT"                       # insert backslash before apostrophe

# split according to csplit variable
csplit "$RAW_TEXT" "/$split/" "{*}"

# create subdirectories and further split files into smaller chunks
new_complex_split "200"

# recursively remove all empty lines and line breaks (needed for Gemma-2 model)
find "${TEMP_ENV}/csplit" -type f -print0 | xargs -0 sed -i '/^$/d;:a;N;$!ba;s/\n/ /g'

# major loop function to only write to file if there is no error message, otherwise, keep trying
call_llama() {
  prompt="<start_of_turn>user In one paragraph, summarize the following content while using direct quotes to highlight impactful statements. Do not use any lists, bullet points, or outlines. Here is the content: $(<"${1}")<end_of_turn><start_of_turn>model"
  llamacpp "$prompt"
  echo "$response" >> "$SUMMARY"
  echo >> "$SUMMARY"
  if [ $? -ne 0 ]; then
    # If there was an error, retry the command
    call_llama "$1"
  fi
}

# loop through the various directories while applying the prompt
for dir in */; do
  echo >> "$SUMMARY"
  echo "## REPORT" >> "$SUMMARY"
  echo >> "$SUMMARY"

  # Loop through each file in the subdirectory
  for file in "$dir"*; do
    if [ -f "$file" ]; then
      # Call the function with the file as an argument
      call_llama "$file"
    fi
  done
done

# optional text processing on summary file
sed -i 's/**//g' "$SUMMARY"															# delete any bold markup
sed 's/[“”"]\{2\}/"/g' "$SUMMARY"													# replace two quote marks with one
sed -i 's/<end_of_turn>//g' "$SUMMARY"												# needed for Gemma-2 model
sed -i -E 's/([A-Z][a-z]{2,8} [0-9]{1,2}[a-zA-Z]{0,2}, [0-9]{4})/**\1**/g' "$SUMMARY"	# highlight dates

# delete repetitive sentences created by Gemma-2 at the start of each paragraph
awk '{gsub(/\<This (report|document|case) (details|provides|concerns|involves)[^.!?]*[.!?]/, ""); print}' "$SUMMARY" > temp && mv temp "$SUMMARY"

# make all quoted text bold
sed -i -E 's/[“"]([^“”"]*)[”"]/**\1**/g' "$SUMMARY"

# convert summary into pdf
md-to-pdf --pdf-options '{"format":"Letter","margin":"18mm 36mm 18mm 36mm"}' --stylesheet "$markdown_css" "$SUMMARY"

# copy completed markdown file to project directory
cp "$SUMMARY" "$PROJ_HOME"

# copy pdf version to project directory
cd "$TEMP_ENV" 
cp CTsummary.pdf "$PROJ_HOME"

# stop Gemma-2 27b
pkill -f gemma
exit
