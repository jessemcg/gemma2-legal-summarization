# gemma2-legal-summarization
Bash scripts for summarizing legal transcripts locally with a variation of [Gemma-2](https://ai.google.dev/gemma/docs). There are two scripts: one for the reporter's transcript, and one of the clerk's transcript. They can be run with simple CLI commands in the terminal. Benefits of local inference are consistency and the ability to keep sensitive data on your computer. This requires a Cuda enabled Nvidia GPU with about 12 gigs of VRAM or more.

A key feature is the liberal use of direct quotes, allowing for easy searches in the source PDF to locate page numbers and surrounding context. Direct quotes appear in bold in the resulting pdf. I have found that Gemma-2 models can follow instructions to mix in direct quotes quite well, but only if the context window is relatively small. Therefore, each paragraph of summary represents 400 lines of the reporter's transcript or 200 lines of the clerk's transcript. The Linux csplit command is used to delineate the start of a hearing or report. All temporary files are stored in memory at: `/dev/shm` Go there to inspect or debug.

Here is a summary of three hearings from Trump's recent hush money trial. The original transcripts were about 500 pages.
 [sample_summary.pdf](https://github.com/user-attachments/files/17075180/sample_summary.pdf)
 
## Set up Dependencies

### Nvida Driver and Cuda Toolkit
You will need both the Nvidia driver and the Cuda toolkit installed. If you are on Fedora Linux, you can avoid a lot of headache by using Fedora 39 (not 40) because it is sure to work with the driver and has the older GCC compiler that the Cuda toolkit requires. In addition, only install the Nvidia driver from the [Fusion Nonfree Repository](https://rpmfusion.org/Howto/NVIDIA). The Cuda toolkit can be installed from the Nvidia servers. See [Fedora Cuda Instructions](https://rpmfusion.org/Howto/CUDA).

### Set up llama.cpp 
Review documentation [here](https://github.com/ggerganov/llama.cpp). For inference on a Cuda enabled GPU, just clone the repo to the home directory:

	git clone https://github.com/ggerganov/llama.cpp.git

Then compile:

	cd $HOME/llama.cpp
	make GGML_CUDA=1

Note: You can add the gguf formatted model later 

### Download Gemma-2 Ataraxy GGUF Model

My new favorite model is [Gemma-2-Ataraxy-9b-GGUF](https://huggingface.co/bartowski/Gemma-2-Ataraxy-9B-GGUF). It was created by merging two fine tuned gemma-2 models, one based on a dataset of high quality writing. For summarization, this seems to work better than the regular Gemma-2 27b, with way less resources needed. I recommend this 6-quant version:

    Gemma-2-Ataraxy-9B-Q6_K.gguf
    
Save it to this directory:

    $HOME/llama.cpp/models

### md-to-pdf

    npm install md-to-pdf

## Clone this Repo

    git clone https://github.com/jessemcg/gemma2-legal-summarization.git

Make sure scripts are executible

    chmod +x $HOME/gemma2-legal-summarization/*

## Prepare Text Files

* Make sure the source pdf is [OCR'ed.](https://en.wikipedia.org/wiki/Optical_character_recognition)
* For the reporter's transcript, optionally use a tool like [pdf slicer](https://flathub.org/apps/com.github.junrrein.PDFSlicer) to removal cover pages and indexes. Then cut and paste everything to a plain text file.
* For the clerk's transcript, cut and paste relevant portions of reports into a different plain text file. Optionally use a phrase like `next-section` at the start of each report to later use with the csplit command. 

## CLI Commands

Preliminarily, you may need to clear the GPU memory because you will need most of the 24 gigs of vram. The way I do it is by logging out and then back in. The CLI commands are very similar. First CD to the project directory:

    cd $HOME/gemma2-legal-summarization
    
Then execute the desired script with the -f flag followed by the desired text file and -s flag following by the desired variable for the csplit command. For example, to summarize the reporter's transcript:

    ./sumRTscript.sh -f raw_rt.txt -s "ORANGE, CALIFORNIA"
    
Note: Often, the same words will appear on the same line as the date for a new hearing. Use those words for the csplit variable so that the start of each hearing is clearly delineated. Because the prompt instructs Gemma-2 to include the date, it will appear at the start of the summary.

Here is an example for the clerk's transcript:

    ./sumCTscript.sh -f raw_ct.txt -s next-section
    
As shown above, if the input text file is located in the project directory, you can just list the file name. However, if the input text file is located elsewhere, you will need to list the entire file path.
