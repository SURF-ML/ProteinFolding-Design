#!/bin/bash

# --- 1. Configuration ---
# Set this to your project's directory on the cluster.
PROJECT_SPACE="./"

# --- Base image is a public CUDA 11.8 image from Docker Hub ---
CONTAINER_BASE="nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04"
CONTAINER_NAME="proteinmpnn-torch2-cuda11.8.sif" # Updated name for clarity
PROTEINMPNN_REPO="https://github.com/dauparas/ProteinMPNN.git"


# --- 2. Sanity Check and Setup ---
if [ -z "$PROJECT_SPACE" ]; then
  echo "Error: PROJECT_SPACE is not set. Please edit this script to set your project space path."
  exit 1
fi

# Recommended: Use shared memory for temporary files during build
export APPTAINER_TMPDIR=/dev/shm/$USER
export APPTAINER_CACHEDIR=/scratch-shared/$USER/apptainer

CONTAINER_OUTPUT_DIR=$PROJECT_SPACE/containers
CONTAINER_OUTPUT_PATH=$CONTAINER_OUTPUT_DIR/$CONTAINER_NAME

mkdir -p $APPTAINER_TMPDIR $APPTAINER_CACHEDIR $CONTAINER_OUTPUT_DIR
echo "Building container at: $CONTAINER_OUTPUT_PATH"


# --- 3. Create Apptainer Definition File ---
TMP_CONTAINER_FILENAME=$APPTAINER_TMPDIR/proteinmpnn.def

cat <<EOF > $TMP_CONTAINER_FILENAME
Bootstrap: docker
From: $CONTAINER_BASE

%post
    # Base OS (Ubuntu 22.04) has Python 3.10 by default
    apt-get -q update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      git python3-pip wget
    
    python3 -m pip install -q -U --no-cache-dir pip
    rm -rf /var/lib/apt/lists/*
    
    # --- Installing PyTorch and dependencies ---
    # As requested, using the newer torch version from the RFdiffusion build.
    echo "Installing Python packages (using PyTorch 2.1.2)..."
    pip install -q --no-cache-dir \
      torch==2.1.2 \
      --extra-index-url https://download.pytorch.org/whl/cu118
      
    # Install other requirements for ProteinMPNN
    pip install -q --no-cache-dir numpy==1.26.4 tqdm

    # --- Clone ProteinMPNN and set up the application ---
    # The repo already contains the model weights. We will copy the whole
    # repository into the /app directory for simplicity and robustness.
    echo "Cloning ProteinMPNN repository..."
    rm -rf /tmp/ProteinMPNN_repo
    git clone $PROTEINMPNN_REPO /tmp/ProteinMPNN_repo
    
    # Move the entire application to a permanent location
    mkdir -p /app
    mv /tmp/ProteinMPNN_repo /app/ProteinMPNN
    
    # Clean up
    rm -rf /tmp/ProteinMPNN_repo

# --- Defining multiple 'apps' for different functionalities ---
# This allows calling specific scripts within the container easily.

%apphelp parse
    This app runs the parse_multiple_chains.py script to prepare PDB files.
    Usage: apptainer run --app parse <container> [script arguments]
    Example: apptainer run --app parse proteinmpnn.sif --input_path ./pdbs --output_path ./parsed

%apprun parse
    exec python3 /app/ProteinMPNN/helper_scripts/parse_multiple_chains.py "\$@"

%apphelp run
    This app runs the main protein_mpnn_run.py design script.
    Usage: apptainer run --app run <container> [script arguments]
    Example: apptainer run --app run proteinmpnn.sif --jsonl_path ./parsed --out_folder ./output

%apprun run
    exec python3 /app/ProteinMPNN/protein_mpnn_run.py "\$@"

EOF


# --- 4. Build the Container ---
echo "Starting Apptainer build..."
apptainer build --fakeroot $CONTAINER_OUTPUT_PATH $TMP_CONTAINER_FILENAME


# --- 5. Clean Up ---
rm $TMP_CONTAINER_FILENAME
echo ""
echo "Done building! Container is ready at:"
echo "$CONTAINER_OUTPUT_PATH"
