#!/bin/bash
#
# usage: 
#
# 

# sbatch options
#SBATCH --job-name=RUN_CREATE_CRIS_HR_RTP
# partition = dev/batch
#SBATCH --partition=batch
# qos = short/normal/medium/long/long_contrib
#SBATCH --qos=normal
#SBATCH --account=pi_strow
#SBATCH -N1
#SBATCH --mem-per-cpu=18000
#SBATCH --cpus-per-task 1
###SBATCH --array=1-540
#SBATCH --time=01:30:00

# matlab options
MATLAB=/usr/cluster/matlab/current/bin/matlab
MATOPT=' -nojvm -nodisplay -nosplash'


#LOGDIR=~/logs/sbatch
#DT=$(date +"%Y%m%d-%H%M%S")

JOBSTEP=0

echo "Executing srun of run_cris_batch"
$MATLAB $MATOPT -r "set_process_dirs; addpath(rtp_sw_dir); run_cris_batch; exit"
    
echo "Finished with run_cris_batch"



