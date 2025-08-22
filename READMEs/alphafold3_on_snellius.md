# Running AlphaFold 3 on Snellius

## Introduction
While proper support for AlphaFold 3 on Snellius is still underway, we temporarily provide a container for the AlphaFold 3 code base. This README provides a brief overview on how to run this container on Snellius, as well as some tips to bypass certain quirks. This README assumes that you've already read the README on AlphaFold 2.

### Table of Contents
1. [Using AlphaFold as a Module](#using-alphafold-as-a-module)
2. [Running AlphaFold with your input](#running-alphafold-with-your-input)
3. [Running inference and data pipeline seperately to avoid wasting resources](#running-inference-and-data-pipeline-seperately-to-avoid-wasting-resources)
4. [Additional Notes](#additional-notes)

---

## Using AlphaFold as a Module

### Loading AlphaFold 3 Module
AlphaFold3 is installed on our systems as a module: `AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0` in the 2024 stack.
And the dataset are found under `/projects/2/managed_datasets/AlphaFold/3.0.0`. Unlike for AlphaFold 2, we currently do *not* host the model weights, which you have to [request these yourself from Google](https://docs.google.com/forms/d/e/1FAIpQLSfWZAgo1aYk0O4MuAXZj8xRQ8DafeFJnldNOnh_13qAx2ceZw/viewform?pli=1).


**To load the AlphaFold Module**:
```
module load 2024
module load AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0
```
In this manner, provided that we allocated a GPU node, we can now execute the ```alphafold-3.0.0.sif``` container.

```alphafold-3.0.0.sif  cmd_args```. To see the arguments needed, see ```alphafold-3.0.0.sif  --help```.

**Note**: This container has been set-up to run https://github.com/google-deepmind/alphafold3/blob/main/run_alphafold.py by default. However, there are some shortcomings here which require us to run it differently in more situations:

1. The container is not configured to properly utilise GPU.
2. Files outside of your home directory, including the path to the AlphaFold 3 data we host on Snellius, are not accesible by default. These need to be bound to be accessible.

To solve these, we can manually execute the following:

```bash
DATA_PATH=/projects/2/managed_datasets/AlphaFold/3.0.0
AF3_CONTAINER_PATH="/sw/arch/RHEL9/EB_production/2024/software/AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0/bin/alphafold-3.0.0.sif"
# Set AF arguments
cmd_args=....

apptainer run --nv \ # --nv passes the Nvidia GPU to the apptainer
   -B "$PWD:/workspace" \ # --B binds a location to the container, in this case the current bash location
   -B ${DATA_PATH} \ # And in this case the path of the data location
   --pwd /workspace \ # --pwd sets the working directory inside the container.
   ${AF3_CONTAINER_PATH}  ${cmd_args} # Running AF3
   ```

where `--nv` allows CUDA usage, and `--B ` allows usage of files in certain locations by binding it to the container.

## Running AlphaFold with your input

### Steps to Run AlphaFold
1. **Prepare Your JSON File**: Unlike AF2, AF3 now requires .json files as input. Ensure that they are correctly formatted.

2. **Prepare the model weights**: Unlike AF2, AF3 does not allow us to host the model weights used for inference on Snellius. Therefore, you will have to [request these yourself from Google](https://docs.google.com/forms/d/e/1FAIpQLSfWZAgo1aYk0O4MuAXZj8xRQ8DafeFJnldNOnh_13qAx2ceZw/viewform?pli=1). 



3. **Create a Job Script**:
   Where for AF2 our 40GB A100 GPUs were sufficient, Deepmind recommends at least an 80GB GPU for inference on inputs up to 5120 tokens. Therefore you might need to use our 94GB H100 GPUs instead. Note that one GPU (1/4 of a node) equates to 16 cores instead of 18.
     ```bash
     #!/bin/bash
      #SBATCH --job-name=AF3_inference        # Name of the job
      #SBATCH --nodes=1                       # Use a single node
      #SBATCH --time=01:30:00                 # Maximum execution time: 90 minutes
      #SBATCH --partition gpu_h100            # Use H100 partition for AF3
      #SBATCH --gpus 1                        # Use a single GPU
      #SBATCH --output=AF3_inference%j.out    # Standard output log
      #SBATCH --error=AF3_inference%j.err     # Standard error log

      # load environment modules
      module load 2024
      module load AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0 
     
      AF3_CONTAINER_PATH="/sw/arch/RHEL9/EB_production/2024/software/AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0/bin/alphafold-3.0.0.sif"

      # Path of the data. Contains both the (large) .fasta files used 
      # for jackhmmer and a simlink to the mmcif files on NVME storage used for 
      # MSA deduplication and template matching. Storing the MMCIF files there
      # massively speeds up these tasks due to the high IOPs requirements of this task.
      DATA_PATH=/projects/2/managed_datasets/AlphaFold/3.0.0

      # Path to the mmcif symlink. For now we point directly to the 'true' 
      # location at /scratch-nvme/ml-datasets/AlphaFold/3.0.0/mmcif_files/. 
      # Setting it to {DATA_PATH}/mmcif_files should also work due to the symlink.
      MMCIF_PATH=/scratch-nvme/ml-datasets/AlphaFold/3.0.0/mmcif_files/

      # --- VARIABLE DEFINITIONS - Only sets these if the variables are not already set---
      # Define the base project directory
      PROJECT_SPACE="./"

      # Path of the original JSON input file used for the data pipeline. Change to the location of your input JSON file.
      INPUT_JSON_PATH="./alphafold3/inputs/fold_input.json"

      # Path where the output files are written to
      OUTPUT_PATH=${PROJECT_SPACE}/alphafold3/outputs/
      # Path to the model weights. Change to the location of your weights
      MODEL_PATH=~/AF3Weights

      cmd_args="--json_path ${INPUT_JSON_PATH}
      --output_dir ${OUTPUT_PATH}
      --model_dir ${MODEL_PATH}
      --db_dir ${DATA_PATH}
      --pdb_database_path ${MMCIF_PATH}"

      # Unset to avoid warnings.
      unset LD_PRELOAD
      # Run the Alphafold 3 pipeline.
      # -B "$PWD:/workspace" mounts the current directory ($PWD) to /workspace inside the container.
      # -B ${DATA_PATH} mounts the data path to the container.
      # --pwd sets the working directory inside the container.
      apptainer run --nv \
         -B "$PWD:/workspace" \
         -B ${DATA_PATH} \
         --pwd /workspace \
         ${AF3_CONTAINER_PATH}  ${cmd_args}
      
     ```

     You will find your outputs under `${PROJECT_SPACE}/alphafold3/outputs/`. 
---

## Running Inference and data pipeline seperately to avoid wasting resources.
When running the full AF3 pipeline there are two main pipelines to consider. The data processing pipeline (e.g. using jackhmmer) and the inference part using the model weights. Only the inference can actually use the GPU, whereas the data processing pipeline can easily take the bulk of the time (in some of my experiments about 15-90 minutes of CPU-only wall-time and only a minute for the GPU-based inference). This is a huge waste of resources!

Instead, please use the  `--run_inference=False` and `--run_data_pipeline=False` (or `--norun_inference` and `--norun_data_pipeline`) flags (both default to True) to [split these two processes in seperate jobs](https://github.com/google-deepmind/alphafold3/blob/main/docs/performance.md#running-the-pipeline-in-stages), with the data pipeline execution on CPU nodes and the inference on GPU nodes. We can create two successive jobs using SLURM job dependencies:

### AF3 data pipeline only (with `--run_inference=False`):
Batch script to only run the AF3 CPU-only data pipeline.

```bash
#!/bin/bash
#
# Slurm submission script for AlphaFold 3 data pipeline only.
#

#SBATCH --job-name=AF3_data         # Name of the job
#SBATCH --nodes=1                   # Use a single node
#SBATCH --time=01:30:00             # Maximum execution time: 1.5 hours
#SBATCH --partition genoa           # Use Genoa CPU partition
#SBATCH --ntasks 1                  # Run a single task
#SBATCH --cpus-per-task 24          # Allocate 24 CPU cores per task. See Note below
#SBATCH --output=AF3_data%j.out     # Standard output log
#SBATCH --error=AF3_data%j.err      # Standard error log

# load environment modules
module load 2024
module load AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0 

# Path of the container that is already hosted in the software stack of Snellius.
AF3_CONTAINER_PATH="/sw/arch/RHEL9/EB_production/2024/software/AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0/bin/alphafold-3.0.0.sif"

# Path of the data. Contains both the (large) .fasta files used for jackhmmer and a simlink to the mmcif files on NVME storage used for MSA deduplication and template matching.
DATA_PATH=/projects/2/managed_datasets/AlphaFold/3.0.0

# Path to the mmcif symlink. For now we point directly to the 'true' location at /scratch-nvme/ml-datasets/AlphaFold/3.0.0/mmcif_files/. 
# Setting it to {DATA_PATH}/mmcif_files should also work due to the symlink
MMCIF_PATH=/scratch-nvme/ml-datasets/AlphaFold/3.0.0/mmcif_files/

# AF3 command line arguments
cmd_args="--json_path ${INPUT_JSON_PATH}
--output_dir ${OUTPUT_PATH}
--db_dir ${DATA_PATH}
--pdb_database_path ${MMCIF_PATH}
--run_inference=False" # Do not run inference

# Unset to avoid warnings.
unset LD_PRELOAD
# Run the Alphafold 3 data pipeline.
# -B "$PWD:/workspace" mounts the current directory ($PWD) to /workspace inside the container.
# -B ${DATA_PATH} mounts the data path to the container.
# --pwd sets the working directory inside the container.
apptainer run -B "$PWD:/workspace" \
    -B ${DATA_PATH} \
    --pwd /workspace \
    ${AF3_CONTAINER_PATH}  ${cmd_args}

```

**Note**: In this script I will use 'only' 24 cores on the Genoa nodes. The main reason for this is that Jackhmmer, the most compute intensive parts of the data-pipeline, only spawns 4 parallel processes with only 8 CPU workers by default per worker. While this can be overridden by default using the `--jackhmmer_n_cpu <num_workers>` flag when calling the AlphaFold 3 container, according to my own experiments and AlphaFold 3's documentation this typically [does *not* result in any measurable speedup](https://github.com/google-deepmind/alphafold3/blob/main/run_alphafold.py#L179). 

This means that a maximum of 4*8=32 cores can be used effectively. However, there is a big difference in the duration of the Jackhmmer processes (e.g. taking 70, 280, 430 and 580 seconds for the 4 processes), which can result in long idling of some cores. Therefore, I did not notice a significant overall speed-up going beyond the minimum allocation, which is 16 for the Rome nodes and 24 for the Genoa nodes.

### AF3 Inference Pipeline (`--run_data_pipeline=False`):
Batch script to only run the AF3 GPU-based inference pipeline.
```bash
#!/bin/bash
#
# Slurm submission script for AlphaFold 3 inference only. 
# Run this after doing the AlphaFold 3 data pipeline.
#

#SBATCH --job-name=AF3_inference        # Name of the job
#SBATCH --nodes=1                       # Use a single node
#SBATCH --time=00:10:00                 # Maximum execution time: 10 minutes
#SBATCH --partition gpu_h100            # Use H100 partition for AF3
#SBATCH --gpus 1                        # Use a single GPU
#SBATCH --output=AF3_inference%j.out   # Standard output log
#SBATCH --error=AF3_inference%j.err    # Standard error log

# load environment modules
module load 2024
module load AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0 

# Path of the container that is already hosted in the software stack of Snellius.
AF3_CONTAINER_PATH="/sw/arch/RHEL9/EB_production/2024/software/AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0/bin/alphafold-3.0.0.sif"


# --- Determine path of pre-processed JSON file ---
# The AF3 data pipeline will use the 'name' field in the input json to create a subdirectory for the output. Retrieve this name to find the output JSON file with the MSAs.
# Change this in case you have it stored in a different location
NAME=$(jq -r '.name' "$INPUT_JSON_PATH" | awk '{print tolower($0)}')
REAL_INPUT_JSON_PATH=${PROJECT_SPACE}/alphafold3/outputs/${NAME}/${NAME}_data.json


# arguments
cmd_args="--json_path ${REAL_INPUT_JSON_PATH}
--output_dir ${OUTPUT_PATH}
--run_data_pipeline=False
--model_dir ${MODEL_PATH}"


# Unset to avoid warnings.
unset LD_PRELOAD
# Run the Alphafold 3 data pipeline.
# --nv for passing the Nvidia GPU
# -B "$PWD:/workspace" mounts the current directory ($PWD) to /workspace inside the container.
# -B ${DATA_PATH} mounts the data path to the container.
# --pwd sets the working directory inside the container.
apptainer run --nv \
    -B "$PWD:/workspace" \
    --pwd /workspace \
    ${AF3_CONTAINER_PATH}  ${cmd_args}

```

### Combined Script
This script will schedule both pipelines from a single script. It uses a completion dependency to schedule the inference part, such that it can only start after the data pipeline only job successfully completes.
```bash
# --- VARIABLE DEFINITIONS---
# Define the base project directory
PROJECT_SPACE="./"

# Path of the input AF3 json file. Change this to the location of your input file.
INPUT_JSON_PATH=${PROJECT_SPACE}/alphafold3/inputs/fold_input.json

# Path where the output files are written to
OUTPUT_PATH=${PROJECT_SPACE}/alphafold3/outputs/
# Path to the model weights. Change to the location of your weights
MODEL_PATH=~/AF3Weights

# First scheduling data pipeline with passed variables and storing job id.
jid1=$(sbatch --parsable --export=PROJECT_SPACE,INPUT_JSON_PATH,OUTPUT_PATH slurm_files/AF3_data.job)
# Scheduling inference job with dependency on data pipeline job.
sbatch --dependency=afterok:$jid1 --export=PROJECT_SPACE,INPUT_JSON_PATH,OUTPUT_PATH,MODEL_PATH slurm_files/AF3_inference.job
```



## Additional Notes
- Feel free to reach out to the high performance machine learning team (contact: bryan.cardenasguevara@surf.nl or lars.veefkind@surf.nl) for further assistance.
- For detailed AlphaFold parameters and information, refer to the [AlphaFold 3 GitHub repository](https://github.com/google-deepmind/alphafold3).
- To request the model weights, see [Deepmind's form](https://docs.google.com/forms/d/e/1FAIpQLSfWZAgo1aYk0O4MuAXZj8xRQ8DafeFJnldNOnh_13qAx2ceZw/viewform?usp=send_form).

---
