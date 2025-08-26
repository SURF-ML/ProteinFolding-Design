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
