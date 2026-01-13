# IPD-Style ProteinMPNN Wrapper on Snellius

This workflow allows you to define constraints (fixed residues, AA bias, symmetry) directly in the Slurm script as simple strings, automatically generating the complex JSON files required by the vanilla model behind the scenes.

### 1. Overview

`proteinmpnn/run_mpnn_cli.py` translates user arguments into MPNN-compatible JSON configuration files (stored in a hidden `.mpnn_temp_files` folder).

### 2. Step-by-Step Guide

1. **Navigate to the Project Root:**
   ```bash
   cd /projects/0/prjs0823/apptainers/
   ```

2. **Configure the Job:**
   Copy the Slurm example and modify it for your specific project.
   ```bash
   cp slurm_files/run_mpnn.job my_folder/run_my_own_mpnn.job
   ```

3. **Submit and Monitor:**
   ```bash
   sbatch my_folder/run_my_own_mpnn.job
   cat mpnn_JOBID.err
   ```

### 3. How to Configure the Run

#### A. Selecting Chains
Define which chain(s) to redesign. Fixed chains are used as structural context.
```bash
CHAINS="A B C"
```

#### B. Fixing Specific Residues (`FIXED_RESIDUES`)
Format: `ChainID` + `ResidueNumber`. Must match PDB numbering.
```bash
FIXED_RESIDUES="A10 A11 B25"
```

#### C. Symmetry / Tied Positions (`TIED_RESIDUES`)
Enforce identical sequences across chains (e.g., for homotrimers).
* **Format:** `ChainIDStart-End, ChainIDStart-End`
* **Requirement:** Innermost ranges must be the same length.
```bash
# Example: Tie residues 1-150 across Chains A, B, and C
TIED_RESIDUES="A1-150, B1-150, C1-150"
```

#### D. Biasing & Omitting Amino Acids
* **BIAS:** `AA:Value` (Negative = less likely, Positive = more likely).
* **OMIT:** String of single-letter codes (e.g., "C" for no Cysteines).
```bash
BIAS="A:-1.0,W:0.5"
OMIT="C"
```

#### E. Expert Flags
* **--use_soluble_model:** Recommended for de novo/soluble protein design to avoid surface hydrophobes.
* **--sampling_temp:** String of values for diversity sweeps (e.g. "0.1 0.2 0.3").

### 4. Full Slurm Execution Example

Ensure you use **Absolute Paths** when running from different directories.

```bash
# --- 1. SETUP VARIABLES ---
PROJECT_DIR="/projects/0/prjs0823"
CONTAINER_PATH="$PROJECT_DIR/apptainers/proteinmpnn/containers/proteinmpnn-torch2-cuda11.8.sif"
WRAPPER_SCRIPT="$PROJECT_DIR/apptainers/proteinmpnn/run_mpnn_cli.py"

INPUT_PDB="/home/user/my_pdbs/trimer.pdb"
OUTPUT_DIR="/scratch/user/results/trimer_01"
mkdir -p "$OUTPUT_DIR"

# --- 2. DESIGN CONSTRAINTS ---
CHAINS="A B C"
TIED="A1-150, B1-150, C1-150"
FIXED="A10 A11"
BIAS="C:-2.0"

# --- 3. RUN ---
apptainer exec --nv \
  --bind "$PROJECT_DIR":"$PROJECT_DIR":rw \
  "$CONTAINER_PATH" \
  python3 "$WRAPPER_SCRIPT" \
  --pdb_path "$INPUT_PDB" \
  --out_folder "$OUTPUT_DIR" \
  --chains_to_design "$CHAINS" \
  --tied_positions "$TIED" \
  --fixed_positions "$FIXED" \
  --bias_AA "$BIAS" \
  --use_soluble_model \
  --sampling_temp "0.1 0.2" \
  --num_seq_per_target 50 \
  --batch_size 10
```
