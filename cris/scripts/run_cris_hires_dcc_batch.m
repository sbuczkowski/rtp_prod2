function run_cris_hires_dcc_batch(cfg)

% grab the slurm array index for this process
    slurmindex = str2num(getenv('SLURM_ARRAY_TASK_ID'));

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

        % build output directory and make sure it exists and/or is
        % creatable before the heavy time sink of actual processing
        asType = 'dcc';

        % pull year and doy from source path string (which is different
        % for each source and likely to change as we have no truly set
        % framework for storing this data.
        % current storage puts source files in paths looking as follows:
        % ccast: /asl/cris/ccast_v2/sdr45_j02_HR/<year>/<doy>/<CrIS_SDR*.mat>
        % noaa: /asl/cris/sdr60_j02/<year>/<doy>/<SCRIF*.h5>
        % nasa: /asl/cris/nasa_l1b/j02/<year>/<doy>/<SNDR*.nc>
        C = strsplit(infile, '/');
        switch cfg.sourcedata
          case {'ccast', 'nasa'}
            year = C{end-1};
            doy = C{end};
          case 'noaa'
            year = C{end-1};
            doy = C{end};
        end
        
        % check for existence of output path and create it if necessary. This may become a source
        % for filesystem collisions once we are running under slurm.
        sPath = fullfile(cfg.outputdir,asType,year);
        if exist(sPath) == 0
            % need to test for failures
            mkdir(sPath);
        end

        % calculate date from year/doy
        dt = yyyymmdd(datetime(str2num(year),1,1) + str2num(doy) - 1);
        
        switch cfg.sourcedata
          case 'ccast'
            fname = sprintf('%s_%s_%s_%s_d%d.rtp', cfg.inst, cfg.model, cfg.rta, asType, dt);

          case 'noaa'
            fname = sprintf('%s_%s_%s_%s_d%d.rtp', cfg.inst, cfg.model, cfg.rta, asType, dt);

          case 'nasa'
            fname = sprintf('%s_%s_%s_%s_d%d.rtp', cfg.inst, cfg.model, cfg.rta, asType, dt);
        end
        
        rtp_outpath = fullfile(sPath, fname);
        if exist(rtp_outpath)
            % rtpwrite will fail if it tries to overwrite
            delete(rtp_outpath)
        end
        
        % call the processing function
        fprintf(1, '> Processing day %s\n', infile)
        [head, hattr, prof, pattr] = create_cris_hires_dcc_rtp(infile, ...
                                                      cfg);

        MAXOBS = 65000;
        if length(prof.rtime) > MAXOBS
            prof = rtp_sub_prof(prof, randperm(length(prof.rtime), MAXOBS));
        end

        % Now save the four types of cris files
        fprintf(1, '>>> Writing output file: %s\n', rtp_outpath);
        rtpwrite(rtp_outpath,head,hattr,prof,pattr);
        fprintf(1, 'Done\n');

    end
end
