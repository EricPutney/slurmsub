#!/bin/bash

### Defaults ###

# Default values for mandatory arguments
python_script=""
config_file=""
log_file="/dev/null"
debug=false
slurm_cmd="sbatch"

### Basic parsing ###

# Function to print usage
usage() {
    echo "Usage: $0 python_script=PYTHON_SCRIPT python_kwargs=\"arg1=val1 arg2=val2 ...\" slurm_options=\"arg1=val1 arg2=val2 ...\" log_file=LOG_FILE"
    exit 1
}

# Parse the mandatory arguments and optional python_kwargs
for ARGUMENT in "$@"; do
    KEY=$(echo $ARGUMENT | cut -f1 -d=)
    VALUE="${ARGUMENT:${#KEY}+1}"

    case $KEY in
    config_file) config_file=$VALUE ;;
    python_script) python_script=$VALUE ;;
    python_kwargs) python_kwargs=$VALUE ;;
    slurm_options) slurm_options=$VALUE ;;
    log_file) log_file=$VALUE ;;
    debug) debug=$VALUE ;;
    slurm_cmd) slurm_cmd=$VALUE ;;
    *)
        echo "Unknown argument: $KEY"
        usage
        ;;
    esac
done

# Check if mandatory arguments are set
if [ -z "$python_script" ]; then
    echo "Missing mandatory arguments."
    usage
fi

# Check if mandatory arguments are set
if [ -z "$config_file" ]; then
    echo "Missing mandatory arguments."
    usage
fi

# Create directory for log_file if it doesn't exist
if [ "$log_file" != "/dev/null" ]; then
    log_path=$(dirname "$log_file")
    if [ ! -d "$log_path" ]; then
        mkdir -p "$log_path"
    fi
fi

### Python script argument parsing ###
# Remove any newlines from $python_kwargs
python_kwargs=$(echo "$python_kwargs" | tr -d '\n')

# Enhanced regex to match key-value pairs where the value can be complex strings, including escaped quotes
regex='([a-zA-Z0-9_]+)=("([^"\\]*(\\.[^"\\]*)*)"|[^"[:blank:]]*)'

# Initialize the parsed arguments string
python_kwargs_parsed=""

# Iterate over matches to the regex template above in the python_kwargs string
while [[ $python_kwargs =~ $regex ]]; do
    # Interpretation of match_result indices ($BASH_REMATCH is a special bash keyword)
    key=${BASH_REMATCH[1]}   # Group 1: key name
    value=${BASH_REMATCH[2]} # Group 2: value, can be quoted or unquoted

    if [ "$debug" = true ]; then
        # Print the matched key-value pair
        echo "DEBUG: Python: Matched key: '$key', value: '$value'"
    fi

    # Handle escaped quotes inside the value if necessary
    value=$(echo "$value" | sed 's/\\"/"/g')

    # Allow and handle empty string values
    value="${value:-}"

    # Remove surrounding quotes if they exist
    if [[ $value == \"*\" ]]; then
        value=${value:1:-1}
    fi

    # Escape inner double quotes
    value=$(echo "$value" | sed 's/"/\\"/g')

    # Remove the matched portion and trim leading spaces
    # Use printf '%s' to handle any special characters
    escaped_match=$(printf '%s' "${BASH_REMATCH[0]}" | sed 's/[]\/$*.^|[]/\\&/g')
    python_kwargs=$(echo "$python_kwargs" | sed -e "s|$escaped_match||" -e 's/^[[:space:]]*//')

    # Determine how to quote the value
    if [[ $value =~ [[:space:]] ]]; then
        if [[ $value == *\"* ]]; then
            # If the value contains double quotes, use single quotes to wrap the entire value
            value="'$value'"
        else
            # Otherwise, use double quotes
            value="\"$value\""
        fi
    fi

    # Construct the key-value pair in the desired format
    python_kwargs_parsed+="--$key $value "
done

# Trim trailing whitespace from the final output
python_kwargs_parsed="${python_kwargs_parsed% }"

### SLURM option argument parsing ###
# Load machine-specific configuration
source $config_file $slurm_cmd # this defines slurm_options_map (and env_activation, if required)

# Parse the slurm_options into SLURM options map
if [ -n "$slurm_options" ]; then
    for OPTION in $slurm_options; do
        OPTION_KEY=$(echo $OPTION | cut -f1 -d=)
        OPTION_VALUE="${OPTION:${#OPTION_KEY}+1}"
        OPTION_VALUE=$(echo $OPTION_VALUE | sed -e 's/^"//' -e 's/"$//') # Remove surrounding quotes

        # Check if OPTION_VALUE indicates a boolean value
        if [[ "$OPTION_VALUE" =~ ^(true|false)$ ]]; then
            # Convert OPTION_VALUE string to boolean
            OPTION_VALUE=$(echo "$OPTION_VALUE" | tr '[:upper:]' '[:lower:]')
            case "$OPTION_VALUE" in
            true) OPTION_VALUE=true ;;
            false) OPTION_VALUE=false ;;
            esac
            slurm_options_map[$OPTION_KEY]=$OPTION_VALUE
        else
            # Update the slurm_options_map with unexpected options
            slurm_options_map[$OPTION_KEY]=$OPTION_VALUE
        fi

        if [ "$debug" = true ]; then
            echo "DEBUG: SLURM: Matched key: '$OPTION_KEY', value: '${slurm_options_map[$OPTION_KEY]}'"
        fi
    done
fi

# Create the SLURM directives from the options map (Generic version (either SBATCH or SALLOC), sbatch is default though)
slurm_options_parsed=""
for KEY in "${!slurm_options_map[@]}"; do
    if [ -n "${slurm_options_map[$KEY]}" ]; then
        # If slurm_cmd is sbatch, use #SBATCH directives. Otherwise, use --key=value directives
        if [ "$slurm_cmd" = "sbatch" ]; then
            slurm_options_parsed+="#SBATCH"
        fi

        # Check if the option is a boolean flag (true or false)
        if [ "${slurm_options_map[$KEY]}" = true ]; then
            slurm_options_parsed+="--$KEY "
        elif [ "${slurm_options_map[$KEY]}" != false ]; then
            slurm_options_parsed+="--$KEY=${slurm_options_map[$KEY]} "
        fi

        # Add newline character to separate directives
        if [ "$slurm_cmd" = "sbatch" ]; then
            slurm_options_parsed+="\n"
        fi
    fi
done

# Properly handle newlines by using a temporary file
slurm_options_parsed=$(echo -e "$slurm_options_parsed")

### Turn everything above into a SLURM submission script ###

if [ "$slurm_cmd" = "sbatch" ]; then
    # Create a temporary SLURM script
    slurm_script=$(mktemp)
    cat <<EOT >$slurm_script
#!/bin/bash
$slurm_options_parsed

# Load environment (if needed)
source ~/.bashrc

# Activate conda env
$env_activation

# Execute the Python script with the parsed keyword arguments
python $python_script $python_kwargs_parsed > $log_file

# saving pids...
echo "PID=$!"
if [ -z "$PID_SAVED" ]; then
    echo "PID empty"
    PID_SAVED=$!
else
    PID_SAVED="$PID_SAVED $!"
fi

echo "SPAWNED PIDs: $PID_SAVED"

# waiting jobs...
trap 'echo "ctrl+c: prog interrupted. terminating child proc: $PID_SAVED"; kill $PID_SAVED; exit 1' INT
echo "waiting jobs..."

wait

echo "jobs finished..."
exit
EOT
    # Debug option: if true, print the SLURM script and exit
    if [ "$debug" = true ]; then
        echo ""
        echo "DEBUG: SLURM script:"
        cat $slurm_script
        exit 0
    fi

    # Submit the SLURM script using sbatch
    sbatch $slurm_script

elif [ "$slurm_cmd" = "salloc" ]; then
    # Create a temporary SLURM script
    slurm_script=$(mktemp)
    cat <<EOT >$slurm_script
#!/bin/bash

# Load environment (if needed)
source ~/.bashrc

# Activate conda env
$env_activation

# Execute the Python script with the parsed keyword arguments
srun python $python_script $python_kwargs_parsed > $log_file
EOT

    # Debug option: if true, print the SLURM script and exit
    if [ "$debug" = true ]; then
        echo ""
        echo "DEBUG: SLURM script:"
        cat $slurm_script

        echo ""
        echo "DEBUG: salloc execution:"
        echo "salloc $slurm_options_parsed bash $slurm_script"
        exit 0
    fi

    # Submit the SLURM script using salloc
    salloc $slurm_options_parsed bash $slurm_script
else
    echo "Unknown SLURM command: $slurm_cmd"
    exit 1
fi
