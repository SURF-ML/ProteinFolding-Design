#!/bin/bash

# --- 1. Configuration ---
# Set this to your project's directory on the cluster.
PROJECT_SPACE="./"

# --- Base image is now a PUBLIC CUDA 12.3 image from Docker Hub ---
CONTAINER_BASE="nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04"
CONTAINER_NAME="rfdiffusion-cuda11.8.sif"


# --- 2. Sanity Check and Setup ---
if [ -z "$PROJECT_SPACE" ]; then
  echo "Error: PROJECT_SPACE is not set. Please edit this script to set your project space path."
  exit 1
fi

export APPTAINER_TMPDIR=/dev/shm/$USER
export APPTAINER_CACHEDIR=/scratch-shared/$USER/apptainer

CONTAINER_OUTPUT_DIR=$PROJECT_SPACE/containers
CONTAINER_OUTPUT_PATH=$CONTAINER_OUTPUT_DIR/$CONTAINER_NAME

mkdir -p $APPTAINER_TMPDIR $APPTAINER_CACHEDIR $CONTAINER_OUTPUT_DIR
echo "Building container at: $CONTAINER_OUTPUT_PATH"


# --- 3. Create Apptainer Definition File ---
TMP_CONTAINER_FILENAME=$APPTAINER_TMPDIR/rfdiffusion.def

cat <<EOF > $TMP_CONTAINER_FILENAME
Bootstrap: docker
From: $CONTAINER_BASE

%post
    # Base OS (Ubuntu 22.04) has Python 3.10 by default
    apt-get -q update && DEBIAN_FRONTEND=noninteractive apt-get install --no-install-recommends -y \
      git python3-pip wget libcurl4
    
    python3 -m pip install -q -U --no-cache-dir pip
    rm -rf /var/lib/apt/lists/*
    
    # --- Installing packages for CUDA 12.1+ to match the base image ---
    echo "Installing Python packages for CUDA 12.1+..."
    pip install -q --no-cache-dir \
      torch==2.1.2 --extra-index-url https://download.pytorch.org/whl/cu118 \
      dgl==1.1.3+cu118 -f https://data.dgl.ai/wheels/cu118/repo.html \
      hydra-core pyrsistent e3nn==0.3.3 wandb==0.12.0 pynvml==11.0.0 decorator==5.1.0 numpy==1.26.4
      
    # Temporarily clone repo to install its components
    # Force removal of dir in case it exists from a failed run
    rm -rf /tmp/RFdiffusion_repo
    git clone https://github.com/RosettaCommons/RFdiffusion.git /tmp/RFdiffusion_repo
    
    # Install SE3Transformer and RFdiffusion packages from the cloned repo
    pip install -q --no-cache-dir /tmp/RFdiffusion_repo/env/SE3Transformer
    pip install -q --no-cache-dir /tmp/RFdiffusion_repo --no-deps
    
    # Download models
    echo "Downloading RFdiffusion models..."
    bash /tmp/RFdiffusion_repo/scripts/download_models.sh /app/RFdiffusion/models
    
    # Make the container portable by copying the run script
    mkdir -p /app/scripts
    cp /tmp/RFdiffusion_repo/scripts/run_inference.py /app/scripts/
    
    echo "Copying RFdiffusion config files..."
    cp -r /tmp/RFdiffusion_repo/config /app/
    
    # Clean up
    rm -rf /tmp/RFdiffusion_repo

%environment
    export DGLBACKEND="pytorch"
    export LD_PRELOAD=

%runscript
    # Point to the stable script location
    echo "Executing RFdiffusion runscript..."
    python3 /app/scripts/run_inference.py "\$@"

EOF


# --- 4. Build the Container ---
echo "Starting Apptainer build..."
apptainer build --fakeroot $CONTAINER_OUTPUT_PATH $TMP_CONTAINER_FILENAME


# --- 5. Clean Up ---
rm $TMP_CONTAINER_FILENAME
echo ""
echo "Done building! Container is ready at:"
echo "$CONTAINER_OUTPUT_PATH"
