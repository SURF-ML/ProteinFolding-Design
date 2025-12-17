# IPD-Style ProteinMPNN Wrapper on Snellius

This workflow allows you to define constraints (fixed residues, AA bias) directly in the Slurm script as simple strings, automatically generating the complex JSON files required by the vanilla model behind the scenes.

### 1. Overview

`proteinmpnn/run_mpnn_cli.py` translates user arguments into MPNN-compatible JSON configuration files (stored in a hidden `.mpnn_temp_files` folder).

### 2. Step-by-Step Guide

Follow this exact sequence to run a design job.

1. **Navigate to the Project Root:**
   It is crucial to be in the base directory (e.g., `apptainers/`) so the relative paths in the script work by default.

   ```bash
   cd /projects/0/prjs0823/apptainers/
   ```

2. **Configure the Job:**
   cp (create your own slurm proteinmpnn job) the Slurm example script to set your own constraints and modify the copied file.

   ```bash
   cp slurm_files/run_mpnn.job my_folder/run_my_own_mpnn.jop
   ```

3. **Submit the Job:**

   ```bash
   sbatch slurm_files/run_mpnn.job
   ```
   *Output example:* `Submitted batch job 17653843`

4. **Check Logs:**
   Verify the job started correctly.

   ```bash
   cat mpnn_17653843.out
   cat mpnn_17653843.err
   ```

5. **Verify Output:**
   Once finished, check the results folder.

   ```bash
   ls out/mpnn_designs/
   ```
   *Expected Output:*
   ```
   seqs  scores  temp_mpnn_files
   ```

### 3. How to Configure the Run

#### A. Selecting Chains

Define which chain(s) ProteinMPNN should redesign. All other chains will be automatically fixed (used as context).

```bash
# Example: Redesign only Chain A
CHAINS="A" 

# Example: Redesign Chain A and Chain B
CHAINS="A B"
```

#### B. Fixing Specific Residues (`FIXED_RESIDUES`)

Prevent specific residues from changing during design. Useful for preserving motifs or active sites.

* **Format:** A space-separated list of `ChainID` + `ResidueNumber`.
* **Important:** The residue numbers must match the input PDB exactly.

```bash
# Example: Fix residues 10, 11, 12, and 13 on Chain A
FIXED_RESIDUES="A10 A11 A12 A13"

# Example: Fix residue 50 on Chain A and residue 25 on Chain B
FIXED_RESIDUES="A50 B25"
```

#### C. Biasing Amino Acids (`BIAS`)

Encourage or discourage specific amino acids globally.

* **Format:** `AminoAcid:BiasValue`, separated by commas.
* **Values:** Negative values (e.g., `-1.0`) make that AA *less* likely. Positive values make it *more* likely.

```bash
# Example: Reduce Alanine (A) significantly, Glycine (G) slightly, and Proline (P) moderately
BIAS="A:-1.0,G:-0.1,P:-0.5"
```

#### D. Omitting Amino Acids (`OMIT`)

Globally ban specific amino acids from being used in the design.

* **Format:** A string of single-letter codes.
* **Standard Practice:** Often set to "C" to prevent free cysteines (disulfide issues). Set to "X" to omit nothing.

```bash
# Example: Do not generate Cysteines
OMIT="C"
```

#### E. Execution Command

The script uses `apptainer exec` to pass these variables to the Python wrapper. Note that variables like `"$FIXED_RESIDUES"` are quoted so Python receives them as a single argument.

### 4. Custom Input/Output Paths

If you are running the script from a different folder, or want your output saved elsewhere (e.g., on Scratch), you must use **Absolute Paths** in the Slurm script.

**Example Scenario:**
* **Wrapper/Container Location:** `/projects/0/prjs0823/apptainers/`
* **Your Input PDB:** `/home/bryanc/my_pdbs/test.pdb`
* **Desired Output:** `/scratch/bryanc/mpnn_results/`

**How to edit `slurm_files/run_mpnn.job`:**

```bash
# --- 1. SETUP VARIABLES ---

# 1. Set PROJECT_SPACE to the ABSOLUTE path where the wrapper/container lives
#    (Do not use "." if you are submitting from elsewhere)
PROJECT_SPACE="/projects/0/prjs0823/apptainers"

# ... (Container and Wrapper paths use PROJECT_SPACE automatically) ...

# 2. Point to your specific input PDB (Absolute Path)
INPUT_PDB="/home/bryanc/my_pdbs/test.pdb"

# 3. Point to your desired output folder (Absolute Path)
OUTPUT_DIR="/scratch/bryanc/mpnn_results"
mkdir -p "$OUTPUT_DIR"
```

When you submit this modified script, it will find the tools in `PROJECT_SPACE`, read your specific PDB, and dump results into your Scratch folder, regardless of where you run `sbatch` from.

* **Example as seen in the SLURM**:
  
We use the environment in the proteinmpnn container.
```
CHAINS="A"
FIXED_RESIDUES="A10 A11 A12 A13"
BIAS="A:-1.0,G:-0.1,P:-0.5"
OMIT="C"

apptainer exec --nv \
  --bind "$PWD":"$PWD":rw \
  "$CONTAINER_PATH" \
  python3 "$WRAPPER_SCRIPT" \
  --pdb_path "$INPUT_PDB" \
  --out_folder "$OUTPUT_DIR" \
  --chains_to_design "$CHAINS" \
  --fixed_positions "$FIXED_RESIDUES" \
  --bias_AA "$BIAS" \
  --omit_AA "$OMIT" \
  --batch_size 5 \
  --num_seq_per_target 10 \
  --sampling_temp 0.25
```
