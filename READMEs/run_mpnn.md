# IPD-Style ProteinMPNN Wrapper on Snellius

This workflow allows you to define constraints (fixed residues, AA bias) directly in the Slurm script as simple strings, automatically generating the complex JSON files required by the vanilla model behind the scenes.

### 1. Overview

`proteinmpnn/run_mpnn_cli.py` translates user arguments into MPNN-compatible JSON configuration files (stored in a hidden `.mpnn_temp_files` folder).


### 2. Quick Start

1. **Edit the Slurm Job:**
   copy and edit `slurm_files/run_mpnn.job` and adjust the variables in the **"CONFIGURE RUN"** section according to what you need.

2. **Submit the Job:**

   ```
   sbatch slurm_files/run_mpnn.job
   
   ```

### 3. How to Configure the Run

#### A. Selecting Chains

Define which chain(s) ProteinMPNN should redesign. All other chains will be automatically fixed (used as context).

```
# Example: Redesign only Chain A
CHAINS="A" 

# Example: Redesign Chain A and Chain B
CHAINS="A B"

```

#### B. Fixing Specific Residues (`FIXED_RESIDUES`)

Prevent specific residues from changing during design. Useful for preserving motifs or active sites.

* **Format:** A space-separated list of `ChainID` + `ResidueNumber`.

* **Important:** The residue numbers must match the input PDB exactly.

```
# Example: Fix residues 10, 11, 12, and 13 on Chain A
FIXED_RESIDUES="A10 A11 A12 A13"

# Example: Fix residue 50 on Chain A and residue 25 on Chain B
FIXED_RESIDUES="A50 B25"

```

#### C. Biasing Amino Acids (`BIAS`)

Encourage or discourage specific amino acids globally.

* **Format:** `AminoAcid:BiasValue`, separated by commas.

* **Values:** Negative values (e.g., `-1.0`) make that AA *less* likely. Positive values make it *more* likely.

```
# Example: Reduce Alanine (A) significantly, Glycine (G) slightly, and Proline (P) moderately
BIAS="A:-1.0,G:-0.1,P:-0.5"

```

#### D. Omitting Amino Acids (`OMIT`)

Globally ban specific amino acids from being used in the design.

* **Format:** A string of single-letter codes.

* **Standard Practice:** Often set to "C" to prevent free cysteines (disulfide issues). Set to "X" to omit nothing.

```
# Example: Do not generate Cysteines
OMIT="C"

```

#### E. Execution Command

The script uses `apptainer exec` to pass these variables to the Python wrapper.

* **Note on Quoting:** Variables like `"$FIXED_RESIDUES"` are quoted so Python receives them as a single argument (e.g., `"A10 A11"` instead of two separate arguments).

* **Sampling:** Adjustable flags include:

  * `--batch_size`: Number of sequences processed at once (GPU dependent).

  * `--num_seq_per_target`: Total sequences to generate.

  * `--sampling_temp`: Controls diversity (lower = more confident/conservative, higher = more diverse).
 
* **Example as seen in the SLURM**:
  
We use the environment in the proteinmpnn container.
```
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
