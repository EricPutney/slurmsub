# Project Name

I made this project because I got tired of writing 100 slurm scripts that were almost identical for jobs that were slightly different. Now, you can just put the python + slurm arguments you want in a single file and the `slurm.sh` helper file will magically construct and execute a proper slurm script.

You can specify a config file with defaults for the machine or type of job you're executing.

Currently supports python jobs submitted either by `sbatch` or `salloc`, which can be controlled with the `slurm_cmd` flag.

## Table of Contents

- [Installation](#installation)
- [Usage](#usage)
- [License](#license)

## Installation

Instructions on how to install the project.

To clone the project, run:

```
git clone https://github.com/EricPutney/slurmsub.git
```


## Usage

Examine the example found in `examples/submission_script.sh`. The basic structure of a submission script defines the python kwargs for the file being run as well as the slurm options needed for this job. These submission scripts are intended to be information dense, with high level parameters defined up front and all of the argument parsing magic being pushed behind the scenes.

The basic structure of a submission script is as follows:

1. Define the python script path and its arguments using variables. For example:
    ```shellscript
    python_script="examples/python_script.py"
    python_kwargs_names=("arg1" "arg2")
    arg1="value1"
    arg2="value2"
    ```

2. Define the slurm arguments and their values using variables. For example:
    ```shellscript
    slurm_kwargs_names=("time" "job__HYPHEN__name")
    time="01:00:00"
    job__HYPHEN__name="example_job"
    ```

3. Generate key-value pairs of python kwargs and slurm options strings using the `generate_kwargs` function. For example:
    ```shellscript
    python_kwargs=$(generate_kwargs "${python_kwargs_names[@]}")
    slurm_options=$(generate_kwargs "${slurm_kwargs_names[@]}")
    ```

4. Run the slurm script with the necessary arguments. For example:
    ```shellscript
    ../slurm.sh config_file=$config_file python_script=$python_script python_kwargs="$python_kwargs" slurm_options="$slurm_options" log_file=$log_file debug=$debug slurm_cmd=$slurm_cmd

To write their own submission script, the user can follow these steps:

1. Create their own `submission_script.sh` file (use whatever filename describes your job)
2. Define the python script path and its arguments as bash environment variables.
3. Define the slurm arguments and their values as bash environment variables.
4. Generate the python kwargs and slurm options strings using `generate_kwargs`.
5. Call `slurm.sh config_file=$config_file python_script=$python_script python_kwargs="$python_kwargs" slurm_options="$slurm_options" log_file=$log_file debug=$debug slurm_cmd=$slurm_cmd`.

The submission script can now be executed directly from the terminal via `./submission_script.sh`. `slurm.sh` will parse the arguments, and then construct and execute a new shell script with the appropriate SLURM directives and python arguments.

## License

The project is licensed under the GNU General Public License (GPL). This is a free, copyleft license that guarantees the freedom to share and change all versions of the program. It allows you to distribute copies of the software, modify it, and use pieces of it in new free programs. The GPL also ensures that recipients of the software receive the same freedoms and have access to the source code. However, it is important to note that the GPL does not provide any warranty for the software. For more information, please refer to the [GNU General Public License](https://www.gnu.org/licenses/gpl-3.0.en.html) document.