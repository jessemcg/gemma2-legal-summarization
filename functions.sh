#!/bin/bash

create_temp_environment() {
	if [ -d "$1" ]; then
		rm -rf "$1"/*
	else
		mkdir "$1"
	fi
}

convert_to_ascii() {
    # Create a temporary file
    tmpfile=$(mktemp)
    
    # Determine the encoding of the input file
    encoding=$(file -bi "$1" | awk -F'=' '{print $2}')
    
    if [ "$encoding" != "us-ascii" ]; then
        # Convert to ASCII if not already in ASCII
        iconv -f "$encoding" -t ASCII//TRANSLIT "$1" -o "$tmpfile"
    else
        # If already in ASCII, simply copy the file
        cp "$1" "$tmpfile"
    fi
    
    # Replace the input file with the temporary file
    mv "$tmpfile" "$1"
}

llamacpp() {
  # define the curl call
  curl_call=$(curl -s http://localhost:8081/v1/chat/completions \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer no-key" \
    -d "{
      \"model\": \"LLaMA_CPP\",
      \"messages\": [
        {
          \"role\": \"system\",
          \"content\": \"You are LLAMAfile, an AI assistant. Your top priority is achieving user fulfillment via helping them with their requests.\"
        },
        {
          \"role\": \"user\",
          \"content\": \"$1\"
        }
      ]
    }")
  
  # use jq to parse the response and extract the desired content
  response=$(echo "$curl_call" | jq -r '.choices[0].message.content' 2>&1)
}

new_complex_split() {
	# move the resulting files into a new director
	mkdir csplit
	mv xx* ./csplit/
	# add .txt to end of each file
	for file in ./csplit/*
	do
		mv "$file" "${file}.txt"
	done
	# create a new directory for each file and place the file in it
	for file in ./csplit/*
	do
		dir="${file%.txt}"
			mkdir -- "$dir"
			mv -- "$file" "$dir"
	done
	# delete the empty file
	rm -r ./csplit/xx00/
	# split all files in each subdirectory and remove original file
	cd ./csplit/
	for dir in */; do
	  # Loop through each file in the subdirectory
	  for file in "$dir"*; do
		if [ -f "$file" ]; then
		  # Split the file into smaller files using the `split` command
		  split -d -l $1 -a 4 "$file" "$file.part"
		  # Delete the original file
		  rm "$file"
		fi
	  done
	done
}
