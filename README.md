# Protein Design Pipeline

This document outlines a computational pipeline for protein design using Apptainer containers.

## RFdiffusion & ProteinMPNN

Currently, this concerns the use of RFD and ProteinMPNN

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

* `PROJECT_SPACE`: Set this to the root directory of your project. The default is `"./"`, under apptainer/.

* `INPUT_PDB_PATH`: The full path to the input PDB file.

* `OUTPUT_PATH`: The directory where all final and intermediate files will be saved.

* **Slurm Parameters**: You should also modify the `#SBATCH` directives at the top of the script (e.g., `--time`, `--gpus`, `--partition`) to match the resource requirements of your specific workflow.

### Notes on Apptainer Usage

* **Overlay File**: The script creates a temporary `rfdiffusion_overlay.img` file. The default size of 128MB is sufficient for these examples. You should increase this size if you are generating a very large number of intermediate files and run into storage errors during the run.

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

## Customizing the Pipeline

You can modify the behavior of both RFdiffusion and ProteinMPNN by changing their command-line arguments directly within the example Slurm scripts. For a more complex example, you can also refer to the `rfd_ppi_binder.job` script, which shows a setup for protein-protein interaction (PPI) binder design.

For a full list of available options and advanced features, please refer to the official documentation for each tool:

* **RFdiffusion**: https://github.com/RosettaCommons/RFdiffusion

* **ProteinMPNN**: https://github.com/dauparas/ProteinMPNN
