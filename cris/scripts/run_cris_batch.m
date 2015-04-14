function run_cris_batch()

addpath(genpath('/home/sbuczko1/git/rtp_prod2'));

% grab the slurm array index for this process
slurmindex = str2num(getenv('SLURM_ARRAY_TASK_ID'));

% File ~/cris-files-process.txt is a list of filepaths to the input
% files or this processing. For the initial runs, this was
% generated by a call to 'ls' while sitting in the directory
% /asl/data/cris/ccast/sdr60_hr/2015: 
%    ls -d1 $PWD/{048,049,050}/*.mat >> ~/cris-files-process.txt
%
% cris-files-process.txt, then, contains lines like:
%    /asl/data/cris/ccast/sdr60_hr/2015/048/SDR_d20150217_t1126169.matq
[status, infile] = system(sprintf('sed -n "%dp" ~/cris-files-process.txt | tr -d "\n"', ...
                                  slurmindex));

% separate out parts of file path. We want to keep the bulk of the
% filename intact but change SDR -> rtp and change the extension to
% rtp as well as we make the output file path
outpath='/asl/data/rtp_cris_slb';
[path, name, ext] = fileparts(infile);
outfile = fullfile(outpath, [strrep(name, 'SDR', 'rtp') '.rtp']);

% call the processing function
create_cris_ccast_hires_rtp(infile, outfile)

end