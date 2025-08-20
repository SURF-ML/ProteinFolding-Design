# Snellius Resources and AlphaFold Usage

## Introduction
Brief guide on how to allocate resources using Slurm on snellius, use AlphaFold as a module, run AlphaFold with your FASTA files, and operate the Multiple Sequence Alignment (MSA) tools. Make sure to change the paths to your specific case.

### Table of Contents
1. [Resource Allocation with Slurm](#resource-allocation-with-slurm)
2. [Using AlphaFold as a Module](#using-alphafold-as-a-module)
3. [Running AlphaFold with Your FASTA](#running-alphafold-with-your-fasta)
4. [Running MSA Tools](#running-msa-tools)

---

## Resource Allocation with Slurm

### Introduction to Slurm
Slurm is a job scheduler used to allocate resources for tasks in an HPC environment.

### Steps to Allocate Resources

1. **Check Available Resources**: Use the `sinfo` command to view available nodes and resources.
   ```
   sinfo
   ```
    
    Other useful commands:
   1. ```squeue -u user```: to see the jobs you are running or are pending.
   2. ```accinfo```
   3. ```salloc```
   4. ```sbatch file_to_run.job```
   5. ```scancel jobid```
   
2. **Submit a Job**:
   - Create a Slurm script (`job_script.sh`) with the necessary resource directives. For example:
     ```bash
     #!/bin/bash
     #SBATCH --job-name=my_job
     #SBATCH --nodes=1
     #SBATCH --time=01:00:00
     #SBATCH --partition gpu
     #SBATCH --gpus 1
     #SBATCH --ntasks 1
     #SBATCH --cpus-per-task 18
     ```
   - Submit the job using `sbatch`. Note that the script will only allocate and do nothing.
     ```
     sbatch job_script.sh
     ```
     
   - Another way of getting an allocation is by doing it interactively on the terminal:
     salloc --time 01:00:00 --partition gpu --gpus 1 --ntasks 1 --cpus-per-task 18.
     
     After the resources have been allocated you are free to use them for 1h on the allocated node.

---

## Using AlphaFold as a Module

### Loading AlphaFold Module
AlphaFold2 is installed on our systems as a module: AlphaFold/2.3.1-foss-2022a-CUDA-11.7.0.
And the dataset alongside the parameter weights are found under /projects/2/managed_datasets/AlphaFold/2.3.1.

We do not have to install the data or the needed alphafold dependencies ourselves.

1. **Load the AlphaFold Module**:
   ```
   module load 2022
   AlphaFold/2.3.1-foss-2022a-CUDA-11.7.0
   ```
   In this manner, provided that we allocated a GPU node, we can now execute the ```alphafold``` command.
   
   ```alphafold cmd_args```. To see the arguments needed, see ```alphafold --help```.
---

## Running AlphaFold with Your FASTA

### Steps to Run AlphaFold
1. **Prepare Your FASTA File**: Ensure your FASTA file (`input.fasta`) is correctly formatted.


2. **Create a Job Script**:
   - Include resource allocation with slurm as we saw above and module loading.
   - Add the AlphaFold command with appropriate flags.
     ```bash
     #!/bin/bash
     #SBATCH --job-name=my_job
     #SBATCH --nodes=1
     #SBATCH --time=01:00:00
     #SBATCH --partition gpu
     #SBATCH --gpus 1
     #SBATCH --ntasks 1
     #SBATCH --cpus-per-task 18
     
     module load 2022
     module load AlphaFold/2.3.1-foss-2022a-CUDA-11.7.0
     
     data_root=/projects/2/managed_datasets/AlphaFold/2.3.1
     project_root=./

     cmd_args="--fasta_paths ${project_root}/inputs/alphafold/fastas/7XTB_5.fasta
        --output_dir ${project_root}/outputs/alphafold/
  	    --db_preset full_dbs 
  	    --data_dir ${data_root}
  	    --max_template_date 2023-03-20"
  	
     alphafold ${cmd_args}
     ```

     You will find your outputs under ```${project_root}/outputs/alphafold```. Here you will find the results per model, the created msas, and the plddt rankings and timings per model.  
3. **Submit the Job**:
   ```
   sbatch alphafold_job.sh
   ```

---

## Running MSA Tools

### Using MSA Tools with AlphaFold
MSA tools are essential for preparing input for AlphaFold but it can take a long time.
It can be especially costly when we only have GPU nodes at our disposal.

We have two ways around this.

1. **MSAs are already precomputed**: you can use ```alphafold --use_precomputed_msas```: Whether to read MSAs that have been written to disk instead of running the MSA tools. The MSA files are looked up in the specified output directory where alphafold is going to store the results, so it must stay the same between multiple runs that are to reuse the MSAs. Note however that the alphafold requires the names of the MSAs to be exactly: 

- Bfd_uniref_hits.a3m
- Mgnify_hits.sto
- Pdb_hits.hhr
- uniref90_hits.sto.

2.  **Precompute the MSAs with jackhmmer and hhblits.**:
    - First, as before, load the modules:
    ```
    module load 2022
    module load AlphaFold/2.3.1-foss-2022a-CUDA-11.7.0
    ```
    - Now, we can use the MSA tools; To create the inputs for alphafold we need to run the following: 

    ```
    jackhmmer -A ./outputs/msa/uniref90_hits.sto --noali --F1 0.0005 --F2 5e-05 --F3 5e-07 --incE 0.0001 -E 0.0001 --cpu 8 -N 1 ./inputs/alphafold/fastas/7XTB_5.fasta /projects/2/managed_datasets/AlphaFold/2.3.1/uniref90/uniref90.fasta
    
    jackhmmer -A ./outputs/msa/mgnify_output.sto --noali --F1 0.0005 --F2 5e-05 --F3 5e-07 --incE 0.0001 -E 0.0001 --cpu 8 -N 1 ./inputs/alphafold/fastas/7XTB_5.fasta /projects/2/managed_datasets/AlphaFold/2.3.1/mgnify/mgy_clusters_2022_05.fa
       
    hhblits -i ./outputs/msa/7XTB_5.fasta -cpu 4 -oa3m ./outputs/msa/bfd_uniref_hits.a3m -n 3 -e 0.001 -maxseq 1000000 -realign_max 100000 -maxfilt 100000 -min_prefilter_hits 1000 -d /projects/2/managed_datasets/AlphaFold/2.3.1/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt -d /projects/2/managed_datasets/AlphaFold/2.3.1/uniref30/UniRef30_2021_03
    ```

    Notice here where the outputs are placed.

3. **Create a Job Script for MSA**:
   - Include the command to run your chosen MSA tool with SBATCH. For example:
     ```bash
     #!/bin/bash
     #SBATCH --job-name=my_job
     #SBATCH --nodes=1
     #SBATCH --time=02:00:00
     #SBATCH --partition genoa
     
     module load 2022 
     module load AlphaFold/2.3.1-foss-2022a-CUDA-11.7.0
     
     jackhmmer -A ./outputs/msa/uniref90_hits.sto --noali --F1 0.0005 --F2 5e-05 --F3 5e-07 --incE 0.0001 -E 0.0001 --cpu 8 -N 1 ./inputs/alphafold/fastas/7XTB_5.fasta /projects/2/managed_datasets/AlphaFold/2.3.1/uniref90/uniref90.fasta
    
     jackhmmer -A ./outputs/msa/mgnify_output.sto --noali --F1 0.0005 --F2 5e-05 --F3 5e-07 --incE 0.0001 -E 0.0001 --cpu 8 -N 1 ./inputs/alphafold/fastas/7XTB_5.fasta /projects/2/managed_datasets/AlphaFold/2.3.1/mgnify/mgy_clusters_2022_05.fa
       
     hhblits -i ./outputs/msa/7XTB_5.fasta -cpu 4 -oa3m ./outputs/msa/bfd_uniref_hits.a3m -n 3 -e 0.001 -maxseq 1000000 -realign_max 100000 -maxfilt 100000 -min_prefilter_hits 1000 -d /projects/2/managed_datasets/AlphaFold/2.3.1/bfd/bfd_metaclust_clu_complete_id30_c90_final_seq.sorted_opt -d /projects/2/managed_datasets/AlphaFold/2.3.1/uniref30/UniRef30_2021_03
     ```
4. **Submit the Job**:
   ```
   sbatch msa_job.sh
   ```

---

## Additional Notes
- Feel free to reach out to the high performance machine learning team (contact: bryan.cardenasguevara@surf.nl) for further assistance.
- For detailed AlphaFold parameters, refer to the [AlphaFold GitHub repository](https://github.com/deepmind/alphafold).

---


