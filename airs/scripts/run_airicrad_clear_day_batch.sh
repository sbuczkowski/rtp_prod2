#!/bin/bash
#
# usage: 
#
# 

# sbatch options
#SBATCH --job-name=RUN_CREATE_AIRS_CLEAR_DAY_RTP
# partition = dev/batch
#SBATCH --partition=high_mem
# qos = short/normal/medium/long/long_contrib
#SBATCH --qos=medium+
#SBATCH --account=pi_strow
#SBATCH -N1
#SBATCH --mem-per-cpu=20000
#SBATCH --cpus-per-task 1
#SBATCH --time=03:59:00

#SBATCH -o /home/sbuczko1/LOGS/sbatch/run_create_airs_clear_day-%A_%a.out
#SBATCH -e /home/sbuczko1/LOGS/sbatch/run_create_airs_clear_day-%A_%a.err

# matlab options
MATLAB=matlab
MATOPT=' -nojvm -nodisplay -nosplash'

echo "Executing srun of run_airs_batch"
$MATLAB $MATOPT -r "disp('>>Starting script');\
                    airs_rtpaddpaths;\
                    cfg=ini2struct('$1');\
                    run_airicrad_clear_day_batch(cfg);\
                    exit"
    
echo "Finished with run_airs_batch"



