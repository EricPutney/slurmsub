# Eric Putney's configuration for Amarel
# Parse the only argument, which is the slurm command being used (valid options are either sbatch or salloc)
slurm_cmd=$1

## Define the SLURM options map
# Generic options
declare -A slurm_options_map=(
    [partition]="gpu"
    [nodes]=1
    [cpus-per-task]=1
    [mem]=14000
    [time]="00:10:00"
    [job-name]="default"
    [gres]="gpu:1"
    [exclude]="cuda[001-008],gpu[005-006],gpuk[001-006]"
)

# Command specific options
if [ "$slurm_options" = "sbatch" ]; then
    slurm_options_map[requeue]=true
    slurm_options_map[gpus-per-node]=1
    slurm_options_map[ntasks]=1
    slurm_options_map[output]="./%j.%N.out"
    slurm_options_map[error]="./%j.%N.err"
elif [ "$slurm_options" = "salloc" ]; then
    slurm_options_map[ntasks-per-node]=1
fi

# Environment activation command
env_activation="conda activate conda_py312"
