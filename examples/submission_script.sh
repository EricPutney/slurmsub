#!/bin/bash

# Name the python script arguments and their values
python_script="examples/python_script.py" # path to the python script relative to slurm.sh
python_kwargs_names=("arg1" "arg2")       # names found here will be captured by the generate_kwargs function
arg1="value1"                             # example argument 1
arg2="value2"                             # example argument 2

# Name the slurm arguments and their values (default SLURM options are defined in the config file)
config_file="../configs/amarel.sh"              # path to the config file relative to the current working directory, these are the options you typically use by default for a given system
slurm_kwargs_names=("time" "job__HYPHEN__name") # names found here will be captured by the generate_kwargs function
time="01:00:00"                                 # job runtime
job__HYPHEN__name="example_job"                 # any slurm options with a hyphen should be replaced with __HYPHEN__ in the variable name

# Name extra arguments
log_file="output.log" # output log file for the python script
debug="true"          # while true, this will just print information about the argument parsing and will print the final slurm command that would be run
slurm_cmd="sbatch"    # can be either sbatch or salloc

# This function generates the key-value pairs for the python_kwargs and slurm_options strings
generate_kwargs() {
    local result=""
    for var in "$@"; do
        # Replace the __HYPHEN__ placeholder with a hyphen for the left-hand side
        formatted_var=$(echo "$var" | sed 's/__HYPHEN__/-/g')
        result+="$formatted_var=\"${!var}\" "
    done
    echo "${result% }" # Trim the trailing space
}

# Generate the python_kwargs string
python_kwargs=$(generate_kwargs "${python_kwargs_names[@]}")
slurm_options=$(generate_kwargs "${slurm_kwargs_names[@]}")

# Run the slurm script
../slurm.sh config_file=$config_file python_script=$python_script python_kwargs="$python_kwargs" slurm_options="$slurm_options" log_file=$log_file debug=$debug slurm_cmd=$slurm_cmd
