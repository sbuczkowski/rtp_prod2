function run_cris_ADL_sdr_hires_allfov_batch(cfg)

addpath ..;    % look one level up for create_* functions
addpath ../util;

% grab the slurm array index for this process
slurmindex = str2num(getenv('SLURM_ARRAY_TASK_ID'));

% offset slurmindex to bypass MaxArraySize boundary
%slurmindex = slurmindex + 19999

chunk = cfg.chunk;
for i = 1:chunk
    dayindex = (slurmindex*chunk) + i;
    fprintf(1, '>>> chunk %d  dayindex %d\n', i, dayindex);
    
    % File ~/cris-files-process.txt is a list of filepaths to the input
    % files or this processing. For the initial runs, this was
    % generated by a call to 'ls' while sitting in the directory
    % /asl/data/cris/ccast/sdr60_hr/2015: 
    %    ls -d1 $PWD/{048,049,050}/*.mat >> ~/cris-files-process.txt
    %
    % cris-files-process.txt, then, contains lines like:
    %    /asl/data/cris/ccast/sdr60_hr/2015/048/SDR_d20150217_t1126169.mat
    [status, infile] = system(sprintf('sed -n "%dp" %s | tr -d "\n"', ...
                                      dayindex, cfg.file_list));

    if strcmp(infile, '')
        break;
    end

    % call the processing function
    [head, hattr, prof, pattr] = create_cris_ADL_sdr_hires_allfov_rtp(infile, ...
                                                      cfg);
    % use fnCrisOutput to generate year and doy strings
    %SCRIF_j01_d20180108_t2351369_e2352067_b00733_c20180112052326962834_ADu_ops.h5
    [gpath, gname, ext] = fileparts(infile);
% $$$     C = strsplit(gpath, '/');
% $$$     cris_yearstr = C{8};
% $$$     cris_doystr = C{9};
    cris_yearstr = '2018';
    cris_doystr = '166';
    % Make directory if needed
    % cris hires data will be stored in
    % /asl/rtp/rtp_cris_ccast_hires/{clear,dcc,site,random}/<year>/<doy>
    %
    asType = {'allfov'};
    for i = 1:length(asType)
        % check for existence of output path and create it if necessary. This may become a source
        % for filesystem collisions once we are running under slurm.
        sPath = fullfile(cfg.outputdir,char(asType(i)),cris_yearstr,cris_doystr);
        if exist(sPath) == 0
            mkdir(sPath);
        end
        
        % Now save the four types of cris files
        fprintf(1, '>>> writing output rtp file... ');
        C = strsplit(gname, '_');
        % output naming convention:
        % <inst>_<model>_<rta>_<filter>_<date>_<time>.rtp
        fname = sprintf('%s_sdr_%s_%s_%s_%s_%s.rtp', cfg.inst, cfg.model, cfg.rta, asType{i}, ...
                        C{3}, C{4});
        rtp_outname = fullfile(sPath, fname);
        rtpwrite(rtp_outname,head,hattr,prof,pattr);
        fprintf(1, 'Done\n');
    end



end