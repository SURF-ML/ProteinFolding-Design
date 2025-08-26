# Introduction
This document outlines computational pipelines for protein design and protein prediction, focussed on using apptainers on Snellius. 

## Table of contents

- [Introduction](#introduction)

- [Protein Design Pipeline](#protein-design-pipeline)  
  - [RFdiffusion & ProteinMPNN](#rfdiffusion--proteinmpnn)  
  - [Overview](#overview)  
  - [How to Run the Pipeline](#how-to-run-the-pipeline)  
  - [Configuration](#configuration)  
    - [Notes on Apptainer Usage](#notes-on-apptainer-usage)  
  - [Running Stages Separately](#running-stages-separately)  
    - [To run ONLY RFdiffusion](#to-run-only-rfdiffusion)  
    - [To run ONLY ProteinMPNN](#to-run-only-proteinmpnn)  

- [Protein Structure Prediction (AF2/3)](#protein-structure-prediction-af23)  
  - [Loading the Modules](#loading-the-modules)  
    - [AlphaFold 2](#alphafold-2)  
    - [AlphaFold 3](#alphafold-3)  
  - [Running the Pipeline](#running-the-pipeline)  
    - [AlphaFold 2](#alphafold-2-1)  
    - [AlphaFold 3](#alphafold-3-1)
  - [Configuration](#configuration-1)
  - [Building your own AlphaFold 3 Container](#bulding-your-own-alphafold-3-container)   

- [Customizing the Pipelines](#customizing-the-pipelines)




# Protein Design Pipeline

This chapter outlines a computational pipeline for protein design using Apptainer containers.

## RFdiffusion & ProteinMPNN

Currently, this concerns the use of RFD and ProteinMPNN.

## Overview

The pipeline automates a two-stage protein design process within a single job:

1. **RFdiffusion (Backbone Scaffolding)**: Generates novel protein backbones (scaffolds) around a user-specified functional motif from an input PDB file.

2. **ProteinMPNN (Sequence Design)**: Immediately designs new, stable amino acid sequences for the backbones generated in the first step.

## How to Run the Pipeline

The entire pipeline can be executed by submitting a single Slurm script.

1. **Configure the script**: Before running, you must modify the variables in `rfd_pmpnn.job` to match your project's file structure. See the **Configuration** section below.

2. **Submit the job**:
   ```
   sbatch slurm_files/rfd_pmpnn.job
   ```

3. **Check the output**: Once the job is complete, the final designed PDBs and FASTA files will be located in the directory specified by the `OUTPUT_PATH` variable.

## Configuration

You must edit the following variables in the Slurm script before submitting:

* `PROJECT_SPACE`: Set this to the root directory of your project. The default is `"./"`.

* `INPUT_PDB_PATH`: The full path to the input PDB file you want to use as a motif or scaffold.

* `OUTPUT_PATH`: The directory where all final and intermediate files will be saved.

* **Slurm Parameters**: You should also modify the `#SBATCH` directives at the top of the script (e.g., `--time`, `--gpus`, `--partition`) to match the resource requirements of your specific workflow.

### Notes on Apptainer Usage

* **Overlay File**: The script creates a temporary `rfdiffusion_overlay.img` file. The default size of 128MB is sufficient for this examples. You should increase this size if you are generating a very large number of intermediate files and run into storage errors during the run.

* **File Binding**: For ProteinMPNN to read the output from RFdiffusion and write its own results, its container needs access to the working directory. This is handled by the `--bind "$PWD":"$PWD":rw` flag in the `apptainer run` command.

## Running Stages Separately

Instead of running the full pipeline, you can also run each stage independently using the dedicated, modifiable job scripts located in the `slurm_files/` directory.

### To run ONLY RFdiffusion:

Use the `rfd_scaffold.job` script. Remember to configure the input and output paths within the file before submitting.
```
sbatch slurm_files/rfd_scaffold.job
```

### To run ONLY ProteinMPNN:

If you already have generated scaffolds, use the `proteinmpnn_example.job` script. Make sure the `OUTPUT_PATH` variable in the script points to the directory containing your scaffold PDB files.
```
sbatch slurm_files/proteinmpnn_example.job
```


# Protein Structure Prediction (AF2/3)
For protein structure prediction we have both AlphaFold 2 and AlphaFold 3 available on the system as pre-installed containers. These are freely available in our [environment modules](https://servicedesk.surf.nl/wiki/spaces/WIKI/pages/30660245/Environment+Modules). For more in-depth information about these, refer to `READMEs/alphafold_on_snellius.md` & `READMEs/alphafold3_on_snellius.md`.

## Loading the Modules
Both AlphaFold 2 and AlphaFold 3 are available as modules on our system, and can be loaded as follows:

### AlphaFold 2
```bash
module load 2022
module load AlphaFold/2.3.1-foss-2022a-CUDA-11.7.0
```
**Note**: the 2022 software stack is *not* available on the H100 GPU nodes. So it should be used on the A100 nodes.
### AlphaFold 3
```bash
module load 2024
module load AlphaFold/3.0.0-foss-2024a-CUDA-12.6.0
```

## Running the Pipeline


Similar as before, there are example SLURM scripts in the `slurm_files` directory for both AlphaFold variants. 

### AlphaFold 2
For AlphaFold 2, this is simply a single script that executes both the CPU only data pipeline and the GPU pipeline in one go. Unfortunately, it does not allow splitting the workload, which would reduce the GPU idling time. This pipeline can be executed using
```bash
sbatch slurm_files/AF2.job
```


### AlphaFold 3
AlphaFold 3 does support splitting the pipeline, allowing us to run the CPU-only data pipeline on CPU nodes and the GPU model inference pipeline on GPU nodes. The two scripts to run are:

```bash
sbatch slurm_files/AF3_data.job
```

and 

```bash
sbatch slurm_files/AF3_inference.job
```

Since the first job needs to complete before the second one starts, we can actually create a dependency for the second job to only start after the first one finishes succesfully:

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

# Path to the container. Uncomment to use the 3.0.1 container. Can also replace it with your own container. 
# Uses the hosted AF 3.0.0 container by default
# AF3_CONTAINER_PATH="/gpfs/work1/0/prjs0859/apptainers/alphafold3/containers/alphafold3_0_1.sif"

# First scheduling data pipeline with passed variables and storing job id.
jid1=$(sbatch --parsable \
  --export=PROJECT_SPACE=$PROJECT_SPACE,INPUT_JSON_PATH=$INPUT_JSON_PATH,OUTPUT_PATH=$OUTPUT_PATH,AF3_CONTAINER_PATH=$AF3_CONTAINER_PATH \
  slurm_files/AF3_data.job)
# Scheduling inference job with dependency on data pipeline job.
sbatch --dependency=afterok:$jid1 \
    --export=PROJECT_SPACE=$PROJECT_SPACE,INPUT_JSON_PATH=$INPUT_JSON_PATH,OUTPUT_PATH=$OUTPUT_PATH,MODEL_PATH=$MODEL_PATH,AF3_CONTAINER_PATH=$AF3_CONTAINER_PATH \
    slurm_files/AF3_inference.job
```

This script can be found in `slurm_files/AF_full_run.sh` and can be executed with:
```bash
bash slurm_files/AF_full_run.sh
```

**Note**: While the apptainer is pre-installed on Snellius with the environment modules, we do need to change some apptainer arguments to properly run it. Therefore we'll still use `apptainer run`, and we'll still have to bind (`-B`) some directories and pass the Nvidia GPU (`--nv`). See `READMEs/AlphaFold3_on_snellius.md` for more information.

### Configuration
Both of these scripts also require some variable configurations, similar as before. Here is a list with some variables to change for both AlphaFold 2 and AlphaFold 3:

* `PROJECT_SPACE`: Set this to the root directory of your project. The default is `"./"`.

* `OUTPUT_PATH`: The directory where all final and intermediate files will be saved.

AlphaFold 2 variables:
* `INPUT_FASTA`: The path of the input fasta protein file.

AlphaFold 3 specific paths

* `INPUT_JSON_PATH`: The path of the input JSON protein file. Used for both the inference and data pipeline. For the data pipeline path the output JSON with MSAs will be written to the `OUTPUT_PATH` depending on the 'name' property in the JSON. In the inference batch script, the name will be determined by reading the name from this input path, after which it will figure out where the data pipeline wrote the processed JSON file. 
* `MODEL_PATH`: Path to the model weights of the AlphaFold 3 model. These are not hosted on Snellius and you have to [request these yourself from Google](https://docs.google.com/forms/d/e/1FAIpQLSfWZAgo1aYk0O4MuAXZj8xRQ8DafeFJnldNOnh_13qAx2ceZw/viewform?pli=1). 
* `AF3_CONTAINER_PATH`: Path to the AF3 container. Defaults to the 3.0.0 version hosted on Snellius in the environment modules. You can also override it to the 3.0.1 version that I prepared in `/gpfs/work1/0/prjs0859/apptainers/alphafold3/containers/alphafold3_0_1.sif`, or point it to one you built yourself (see below).

## Bulding your own AlphaFold 3 container.
Currently, we only host the 3.0.0 release of AlphaFold 3 in the Snellius environment modules. Version 3.0.1 already supports some [new functionalities](https://github.com/google-deepmind/alphafold3/releases/tag/v3.0.1) and improvements, and there might be future releases with even more functionality. For this reason you might want to build your own container. I have prepared a definition file in `apptainers/alphafold3/alphafold3.def`. You can adapt this file to your needs by alterting the `alphafold_version=3.0.1` flag to reflect the proper version, and optionally include other flags suitable for your specific usecase. Refer to the AlphaFold 3 documentation for examples. [Here are some examples](https://github.com/google-deepmind/alphafold3/blob/main/docs/performance.md).

You can subsequently build the container:

```bash
apptainer build --fakeroot <PATH_TO_OUTPUT_FILE>.sif apptainers/alphafold3/alphafold3.def
```

This will take some time, and export your container in a `.sif` file you can then pass to the `AF_CONTAINER_PATH` argument.


# Customizing the pipelines
You can modify the behavior of all pipelines by changing their command-line arguments directly within the example Slurm scripts. For a more complex example, you can also refer to the `rfd_ppi_binder.job` script, which shows a setup for protein-protein interaction (PPI) binder design.

For a full list of available options and advanced features, please refer to the official documentation for each tool:

* **RFdiffusion**: https://github.com/RosettaCommons/RFdiffusion

* **ProteinMPNN**: https://github.com/dauparas/ProteinMPNN

* **AlphaFold 2**: https://github.com/google-deepmind/alphafold

* **AlphaFold 3**: https://github.com/google-deepmind/alphafold3





