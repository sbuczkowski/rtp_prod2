#!/bin/bash
#
# usage: 
#
# 

# sbatch options
#SBATCH --job-name=RUN_CREATE_CRIS_HIRES_DCC_RTP
#SBATCH --partition=high_mem
# qos = short/normal/medium/long/long_contrib
#SBATCH --qos=medium+
#SBATCH --account=pi_strow
#SBATCH -N1
#SBATCH --mem-per-cpu=18000
#SBATCH --cpus-per-task 1
##SBATCH --array=0-17#
#SBATCH --time=04:59:00

#SBATCH -o /home/sbuczko1/LOGS/sbatch/run_cris_hires_dcc_batch-%A_%a.out
#SBATCH -e /home/sbuczko1/LOGS/sbatch/run_cris_hires_dcc_batch-%A_%a.err

# matlab options
MATLAB=matlab
MATOPT=' -nojvm -nodisplay -nosplash'

echo "Executing srun of run_cris_batch"
$MATLAB $MATOPT -r "disp('>>Starting script'); rtp_addpaths;cfg=ini2struct('$1');run_cris_ccast_hires_dcc_day_batch(cfg); exit"
    
echo "Finished with run_cris_batch"



