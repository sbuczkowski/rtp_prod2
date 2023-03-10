function run_rtp_create_allfov_gran(cfgfile)

% establish local directory structure
currentFilePath = mfilename('fullpath');
[cfpath, cfname, cfext] = fileparts(currentFilePath);
fprintf(1,'* Executing routine: %s\n', currentFilePath);

% grab the slurm array index for this process
slurmarrayindex = str2num(getenv('SLURM_ARRAY_TASK_ID'));

%*************************************************
% Read in and Validate configuration *************
% check for existence of necessary keywords in cfg. If anything
% necessary is missing, fail with message identifying reason
fprintf(1, '** Configuration\n');
fprintf(1, '*** Validating config file path... ');
if ~isfile(cfgfile)
    fprintf(2, '*** %s: Path to config file invalid: %s\n',cfname, ...
            cfgfile);
    fprintf(1, 'FAILED\n');
    return
end
fprintf(1, 'SUCCEEDED\n');

cfg = ini2struct(cfgfile);

fprintf(1, '*** Validating configuration... ');
if ~is_config_valid(cfg)
    fprintf(1, 'FAILED\n');
    return
end
fprintf(1, 'SUCCEEDED\n');
%*************************************************


chunk = cfg.chunk;
for i = 1:chunk
    dayindex = (slurmarrayindex*chunk) + i;
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
    [status, granfile] = system(sprintf('sed -n "%dp" %s | tr -d "\n"', ...
                                     dayindex, cfg.file_list))
    if strcmp(granfile, '')
        break;
    end

    [head,hattr,prof,pattr] = rtp_create_allfov_gran(granfile, ...
                                                     cfg);
    
    % need to be able to check for failure in the create rtp
    % functions and below. How best to do this?

    % Build output path and filename
    [outpath, outfilename] = rtp_build_output(granfile, cfg);

    % check that output path is valid. If it does not already
    % exist, create it
    fprintf(1, '>>> Writing output rtp to directory %s\n', sPath);
    if exist(outpath) == 0
        fprintf(1, '>>>> %s does not exist. Creating\n', sPath);
        mkdir(outpath);
    end

    % write output file (for granules, we can assume that a granule
    % will always fit within rtp 2GB filesize limit
    switch cfg.inst
      case 'iasi'
        rtpwrite_12(fullfile(outpath, outfilename),head, hattr, prof, ...
                    pattr);
      otherwise
        rtpwrite(fullfile(outpath, outfilename), head, hattr, prof, ...
                 pattr);
    end
end
    
