function [head, hattr, prof, pattr] = create_airicrad_random_day_rtp(inpath, cfg)
%
% NAME
%   create_airicrad_random_day_rtp -- wrapper to process AIRICRAD to RTP
%
% SYNOPSIS
%   [head, hattr, prof, pattr] = create_airicrad_random_day_rtp(inpath, cfg)
%
% INPUTS
%    inpath :   path to day of input AIRICRAD hdf granules
%    cfg    :   configuration struct
%
% DISCUSSION (TBD)
func_name = 'create_airicrad_random_day_rtp';

% establish local directory structure
currentFilePath = mfilename('fullpath');
[cfpath, cfname, cfext] = fileparts(currentFilePath);
fprintf(1,'> Executing routine: %s\n', currentFilePath);

%*************************************************
% Build configuration ****************************
% $$$ klayers_exec = '/asl/packages/klayersV205/BinV201/klayers_airs_wetwater';
% $$$ sartaclr_exec   = '/asl/packages/sartaV108/BinV201/sarta_apr08_m140_wcon_nte';
% $$$ sartacld_exec   = '/asl/packages/sartaV108/BinV201/sarta_apr08_m140_iceGHMbaum_waterdrop_desertdust_slabcloud_hg3';
klayers_exec = cfg.klayers_exec;
sartaclr_exec   = cfg.sartaclr_exec;
sartacld_exec   = cfg.sartacld_exec;
%*************************************************

%*************************************************
% Build traceability info ************************
[status, ghash] = githash();
RunDate = char(datetime('now','TimeZone','local','Format', ...
                        'd-MMM-y HH:mm:ss Z'));
fprintf(1, '>>> Run executed %s with git hash %s\n', ...
        RunDate, ghash);
%*************************************************

load(fullfile(cfpath, 'static/sarta_chans_for_l1c.mat'));

% This version operates on a day of AIRICRAD granules and
% concatenates the subset of random obs into a single output file
% >> inpath is the path to an AIRS day of data
% /asl/data/airs/AIRICRAD/<year>/<doy>
files = dir(fullfile(inpath, '*.hdf'));

for i=1:length(files)
    % Read the AIRICRAD file
    infile = fullfile(inpath, files(i).name);
    fprintf(1, '>>> Reading input file: %s   ', infile);
    try
        [eq_x_tai, freq, prof0, pattr] = read_airicrad(infile);
    catch
        fprintf(2, ['>>> ERROR: failure in read_airicrad for granule %s. ' ...
                    'Skipping.\n'], infile);
        continue;
    end
    fprintf(1, 'Done. \n')
    
    if i == 1 % only need to build the head structure once but, we do
              % need freq data read in from first data file
              % Header 
        head = struct;
        head.pfields = 4;  % robs1, no calcs in file
        head.ptype = 0;       
        head.ngas = 0;
        
        % Assign header attribute strings
        hattr={ {'header' 'pltfid' 'Aqua'}, ...
                {'header' 'instid' 'AIRS'}, ...
                {'header' 'pfields' '[1=profile,2=calc,4=obs (val=sum)]'}, ...
                {'header' 'ptype' '[0=levels,1=layers,2=AIRS layers]'}, ...
                {'header' 'githash' ghash}, ...
                {'header' 'rundate' RunDate}, ...
                {'header' 'klayers_exec' klayers_exec}, ...
                {'header' 'sartaclr_exec' sartaclr_exec}, ...
                {'header' 'sartacld_exec' sartacld_exec}, ...
                {'header' 'source' inpath}, ...
                {'header' 'rtime' 'TAI:1958'}};
        
        
        nchan = size(prof0.robs1,1);
        %vchan = aux.nominal_freq(:);
        vchan = freq;
        
        % Assign header variables
        head.instid = 800; % AIRS 
        head.pltfid = -9999;
        head.nchan = length(ichan);
        head.ichan = ichan;
        head.vchan = vchan;
        head.vcmax = max(head.vchan);
        head.vcmin = min(head.vchan);
        fprintf(1, '>> Header struct built\n');

    end  % end if i == 1

    p = equal_area_nadir_select(prof0,cfg);  % select for
                                             % random/nadir obs
    fprintf(1, '>>>> SAVING %d random obs from granule\n', ...
            length(p.rlat));

    if i == 1
        prof = p;
    else
        % concatenate new random rtp data into running random rtp structure
        [head, prof] = cat_rtp(head, prof, head, p);
    end
end  % end for i=1:length(files)
clear prof0 p;

%*************************************************
% rtp data massaging *****************************
% Fix for zobs altitude units
if isfield(prof,'zobs')
    prof = fix_zobs(prof);
end

%*************************************************
% Add in model data ******************************
fprintf(1, '>>> Add model: %s...', cfg.model)
switch cfg.model
  case 'ecmwf'
    [prof,head,pattr]  = fill_ecmwf(prof,head,pattr);
  case 'era'
    [prof,head,pattr]  = fill_era(prof,head,pattr);
  case 'merra'
    [prof,head,pattr]  = fill_merra(prof,head,pattr);
end
% check that we have same number of model entries as we do obs because
% corrupt model files will leave us with an unbalanced rtp
% structure which WILL fail downstream (ideally, this should be
% checked for in the fill_* routines but, this is faster for now)
[~,nobs] = size(prof.robs1);
[~,mobs] = size(prof.gas_1);
if mobs ~= nobs
    fprintf(2, ['*** ERROR: number of model entries does not agree ' ...
                'with nobs ***\n'])
    return;
end

head.pfields = 5;
if ~isempty(cfg.gasscale_opts)
    %%*** add Chris' gas scaling code ***%%
    % add CO2 from GML
    %disp(‘adding GML CO2’)
    if(cfg.gasscale_opts.scaleco2)
        [head, hattr, prof] = fill_co2(head, hattr, prof);
    end
    % add CH4 from GML
    if(cfg.gasscale_opts.scalech4)
        [head, hattr, prof] = fill_ch4(head, hattr, prof);
    end
    % add N2O from GML
    if(cfg.gasscale_opts.scalen2o)
        [head, hattr, prof] = fill_n2o(head, hattr, prof);
    end
    % add CO from MOPITT
    % %if(ismember(5, opts2.glist))
    % %  [head, hattr, prof] = fill_co(head,hattr,prof);
    % %end
    %%*** end Chris' gas scaling code ***%%
end
fprintf(1, 'Done\n');
%*************************************************

%*************************************************
% Add surface emissivity *************************
% Dan Zhou's one-year climatology for land surface emissivity and
% standard routine for sea surface emissivity
fprintf(1, '>>> Running rtp_add_emis...');
try
    [prof,pattr] = rtp_add_emis(prof,pattr);
catch
    fprintf(2, '>>> ERROR: rtp_add_emis failure for %s/%s\n', sYear, ...
            sDoy);
    return;
end
fprintf(1, 'Done\n');
%*************************************************


%*************************************************
% Save the rtp file ******************************
fprintf(1, '>>> Saving first rtp file... ');
[sID, sTempPath] = genscratchpath();
fn_rtp1 = fullfile(sTempPath, ['airs_random' sID '_1.rtp']);
rtpwrite(fn_rtp1,head,hattr,prof,pattr)
fprintf(1, 'Done\n');

fprintf(1, '>>> Writing klayers input temp file %s ...', fn_rtp1);
rtpwrite(fn_rtp1,head,hattr,prof,pattr)
fprintf(1, 'Done\n')
fn_rtp2 = fullfile(sTempPath, ['airs_random' sID '_2.rtp']);
unix([cfg.klayers_exec ' fin=' fn_rtp1 ' fout=' fn_rtp2 ' > ' sTempPath ...
      '/klayers_' sID '_stdout'])
fprintf(1, 'Done\n');

% scale gas concentrations, if requested in config
if ~isempty(cfg.gasscale_opts)
    fprintf(1, '>>> Post-klayers linear gas scaling...')
    % read in klayers output
    [hh,hha,pp,ppa] = rtpread(fn_rtp2);
    delete(fn_rtp2)
    if isfield(cfg.gasscale_opts, 'scaleco2')
        fprintf(1, '\n\t\tCO2...')
        pp.gas_2 = pp.gas_2 * cfg.gasscale_opts.scaleco2;
        ppa{end+1} = {'profiles' 'scaleCO2' sprintf('%f', cfg.gasscale_opts.scaleco2)};
    end
    if isfield(cfg.gasscale_opts, 'scalech4')
        fprintf(1, '\n\t\tCH4...')
        pp.gas_6 = pp.gas_6 * cfg.gasscale_opts.scalech4;
        ppa{end+1} = {'profiles' 'scaleCH4' sprintf('%f', cfg.gasscale_opts.scalech4)};        
    end
    %%*** Chris' fill_co is not ready so use basic scaling for now
    if isfield(cfg.gasscale_opts,'scaleco')
        fprintf(1, '\n\t\tCO...')
        pp.gas_5 * cfg.gasscale_opts.scaleco;
        ppa{end+1} = {'profiles' 'scaleCO' sprintf('%f', cfg.gasscale_opts.scaleco)};
    end
    %%***
    rtpwrite(fn_rtp2,hh,hha,pp,ppa)
    fprintf(1, 'Done\n')
end

% call klayers/sarta cloudy **********************
fprintf(1, '>>> Running driver_sarta_cloud for both klayers and sarta\n');
run_sarta.cloud=cfg.sarta_cld;
run_sarta.clear=cfg.sarta_clr;
run_sarta.cumsum=cfg.sarta_cumsum;
run_sarta.klayers_code=klayers_exec;
run_sarta.sartaclear_code=sartaclr_exec;
run_sarta.sartacloud_code=sartacld_exec;

[prof0, oslabs] = driver_sarta_cloud_rtp(head,hattr,prof,pattr,run_sarta);

% NEED ERROR CHECKING

% pull calcs out of prof0 and stuff into pre-klayers prof
[~,~,prof,~] = rtpread(fn_rtp1);
prof.rclr = prof0.rclr;
prof.rcld = prof0.rcld;

% also capture cloud fields
prof.cfrac = prof0.cfrac;   
prof.cfrac12 = prof0.cfrac12; 
prof.cfrac2 = prof0.cfrac2;  
prof.cngwat = prof0.cngwat;  
prof.cngwat2 = prof0.cngwat2; 
prof.cprbot = prof0.cprbot;  
prof.cprbot2 = prof0.cprbot2; 
prof.cprtop = prof0.cprtop;  
prof.cprtop2 = prof0.cprtop2; 
prof.cpsize = prof0.cpsize;  
prof.cpsize2 = prof0.cpsize2; 
prof.ctype = prof0.ctype;   
prof.ctype2 = prof0.ctype2;  
prof.co2ppm = prof0.co2ppm;

%*************************************************
% Make head reflect calcs
head.pfields = 7;  % robs, model, calcs


fprintf(1, 'Done\n');


