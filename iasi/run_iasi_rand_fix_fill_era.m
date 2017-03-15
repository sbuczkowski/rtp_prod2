function run_iasi_rand_fix_fill_era()

% 
iasi_daily_file_list = '~/iasi-days-to-process';

% grab the slurm array index for this process
slurmindex = str2num(getenv('SLURM_ARRAY_TASK_ID'));
%slurmindex = 0;

% for each slurm array index, process 30 days from the to-process
% list (because each day takes less time to process than it takes
% to load matlab so, it is inefficient to do each day as a
% separate array)
chunk = 12;
for i = 1:chunk
    dayindex = (slurmindex*chunk) + i;
    %    dayindex=281; % testing testing testing
    fprintf(1, '>>> chunk %d    dayindex %d\n', i, dayindex);
    
    % File ~/cris-files-process.txt is a list of filepaths to the input
    % files or this processing. For the initial runs, this was
    % generated by a call to 'ls' while sitting in the directory
    % /asl/data/cris/ccast/sdr60_hr/2015: 
    %    ls -d1 $PWD/{048,049,050}/*.mat >> ~/cris-files-process.txt
    %
    % cris-files-process.txt, then, contains lines like:
    %    /asl/data/cris/ccast/sdr60_hr/2015/048/SDR_d20150217_t1126169.mat
    [status, inpath] = system(sprintf('sed -n "%dp" %s | tr -d "\n"', ...
                                     dayindex, iasi_daily_file_list));
    if strcmp(inpath, '')
        break;
    end

    fprintf(1, 'run_iasi_rand_fix_fill_era: processing %s\n', inpath);

    iasi_rtp_random_fix_fill_era(inpath);
end
