# ColabFold Running Instructions

This setup uses the globally installed Apptainer container and model weights. You do not need to install anything.

### 1. Environment Setup

Load the modules to enable GPU support.

```bash
module load 2024
module load CUDA/12.6.0
```

### 2. Prepare Output Directory

```bash
mkdir -p output
```

### 3. Run Prediction

#### General Syntax

The container and data paths are fixed. You only need to modify the **input mapping** to point to your specific FASTA folder.

* **`-B <YOUR_LOCAL_FASTA_DIR>:/inputs`**: Maps the folder containing your FASTA files on the cluster to `/inputs` inside the container.

* **`colabfold_batch /inputs/<FILENAME> ...`**: Tells the software to grab the specific file from that mapped folder.

```bash
apptainer run --nv \
  --env PYTHONNOUSERSITE=1 \
  -B /projects/2/managed_datasets/AlphaFold/2.3.1:/data \
  -B /projects/0/prjs0823/colabfold_cache/params:/data/params \
  -B <YOUR_LOCAL_FASTA_DIR>:/inputs \
  -B ./output:/results \
  /projects/0/prjs0823/colabfold_cache/apptainer/colabfold_1.5.5.sif \
  colabfold_batch /inputs/<YOUR_FASTA_FILENAME> /results --data /data --num-models 3
```

#### Specific Example (7XTB)

Running the specific `rcsb_pdb_7XTB.fasta` located in the shared MLProtein_Suite directory:

```bash
apptainer run --nv \
  --env PYTHONNOUSERSITE=1 \
  -B /projects/2/managed_datasets/AlphaFold/2.3.1:/data \
  -B /projects/0/prjs0823/colabfold_cache/params:/data/params \
  -B /projects/0/prjs0823/MLProtein_Suite/ml/inputs/alphafold/fastas:/inputs \
  -B ./output:/results \
  /projects/0/prjs0823/colabfold_cache/apptainer/colabfold_1.5.5.sif \
  colabfold_batch /inputs/rcsb_pdb_7XTB.fasta /results --data /data --num-models 3
```

### 4. Running with Slurm

#### Interactive Job (Testing)
To request a GPU interactively for testing:

```bash
salloc --time 00:30:00 --partition gpu_a100 --gpus 1
```

Once the job starts, load the modules (Step 1) and run the `apptainer` command (Step 3).

#### Batch Script (sbatch)
Save the following as `run_colabfold.sh` and submit with `sbatch run_colabfold.sh`.

```bash
#!/bin/bash
#SBATCH --job-name=colabfold_7XTB
#SBATCH --output=colabfold_%j.out
#SBATCH --error=colabfold_%j.err
#SBATCH --time=00:30:00
#SBATCH --partition=gpu_a100
#SBATCH --gpus=1

# 1. Load Environment
module purge
module load 2024
module load CUDA/12.6.0

# 2. Prepare Output
mkdir -p output_slurm

# 3. Run Prediction
# Note: output directory changed to ./output_slurm to avoid conflicts
apptainer run --nv \
  --env PYTHONNOUSERSITE=1 \
  -B /projects/2/managed_datasets/AlphaFold/2.3.1:/data \
  -B /projects/0/prjs0823/colabfold_cache/params:/data/params \
  -B /projects/0/prjs0823/MLProtein_Suite/ml/inputs/alphafold/fastas:/inputs \
  -B ./output_slurm:/results \
  /projects/0/prjs0823/colabfold_cache/apptainer/colabfold_1.5.5.sif \
  colabfold_batch /inputs/rcsb_pdb_7XTB.fasta /results --data /data --num-models 3
```

### Important Notes

* **Do not change** the `-B ...:/data` or `-B ...:/data/params` lines; these point to the global data and weights.

* **`--env PYTHONNOUSERSITE=1`** is required to prevent conflicts with your local Python libraries.

* **`--nv`** is required for GPU acceleration.
