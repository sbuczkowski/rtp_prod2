function [head, hattr, prof, pattr] = create_cris_ADL_sdr_hires_allfov_rtp(fnCrisInput, cfg)
% PROCESS_CRIS_HIRES process one granule of CrIS data
%
% Process a single CrIS hires .mat granule file.
funcname = 'create_cris_ADL_sdr_hires_allfov_rtp';

fprintf(1, '>> Running %s for input: %s\n', funcname, fnCrisInput);

addpath(genpath('/asl/matlib'));
% Need these two paths to use iasi2cris.m in iasi_decon
addpath /asl/packages/iasi_decon
addpath /asl/packages/ccast/source
addpath /home/sbuczko1/git/ccast/motmsc/utils  % read_SCRIF
addpath /asl/matlib/aslutil   % int2bits
% $$$ addpath /asl/packages/time    % iet2tai (in ccast2rtp)
% $$$ addpath /asl/packages/rtp_prod2/cris;  % ccast2rtp
addpath /home/sbuczko1/git/ccast/test % read_SCRIS

% $$$ addpath /asl/packages/rtp_prod2/grib;  % fill_era/ecmwf
addpath /home/sbuczko1/git/rtp_prod2_DEV/grib;  % fill_era/ecmwf
addpath /home/sbuczko1/git/rtp_prod2_DEV/emis;  % add_emis
addpath /home/sbuczko1/git/rtp_prod2_DEV/util;  % rtpread/write
addpath /home/sbuczko1/git/matlib/clouds/sarta  %
                                                % driver_cloud... (version
                                                % in /asl/matlib
                                                % has typos)
% $$$ addpath /home/sbuczko1/git/matlab2012/cris/readers  % sdr read
% $$$                                                     % functions
addpath /home/sbuczko1/git/rtp_prod2_DEV/cris/readers % sdr read
                                                      % function

addpath /home/sbuczko1/git/rtp_prod2_DEV/cris/util  % build_satlat
addpath /home/sbuczko1/git/rtp_prod2_DEV/util  % genscratchpath
addpath /home/sbuczko1/git/rtp_prod2_DEV/util/time % time functions

[sID, sTempPath] = genscratchpath();

cfg.sID = sID;
cfg.sTempPath = sTempPath;

% check for validity of guard channel specifications
nguard = cfg.nguard;
nsarta = cfg.nsarta;
if nguard > nsarta
    fprintf(2, ['*** Too many guard channels requested/specified ' ...
                '(nguard/nsarta = %d/%d)***\n'], nguard, nsarta);
    return
end

% Load up rtp
fprintf(1, '> Reading in granule file %s\n', fnCrisInput);
[prof, pattr] = readsdr_rtp(fnCrisInput);

% load up profile attributes
% $$$ [~, ~, attr] = read_SCRIF(fnCrisInput);  % Hires
% $$$ [~, ~, attr] = read_SCRIS(fnCrisInput);  % lowres

% $$$ ADind = attr.Ascending_Descending_Indicator;
% $$$ if length(ADind) > 1
% $$$     fprintf(2, '** Multiple asc/desc indicators found **\n');
% $$$     return
% $$$ end
% $$$ prof.iudef(4,:) = ones(1,length(prof.rtime),'int32') * int32(ADind);
prof.iudef(4,:) = (prof.solzen < 90.0);

%-------------------
% set header values
%-------------------
head = struct;
load '/home/sbuczko1/git/rtp_prod2/cris/CrIS_ancillary'
head.nchan = nchan;
head.ichan = ichan;
head.vchan = vchan;
% $$$ head.ichan = cris_ichan(nguard, nsarta, nLW, nMW, nSW);
% $$$ head.vchan = cris_vchan(nguard, userLW, userMW, userSW);
head.pfields = 4; % 4 = IR obs

%-----------------------
% set header attributes
%-----------------------
hattr = {{'header', 'instid', 'CrIS'}, ...
         {'header', 'reader', 'readsdr_rtp'}, ...
        };

% check ichan index order (to avoid problems with rtpwrite)
temp = size(head.ichan);
if temp(2) > 1
    head.ichan = head.ichan';
end
temp = size(head.vchan);
if temp(2) > 1
    head.vchan = head.vchan';
end

% Need this later
ichan_ccast = head.ichan;

% build sub satellite lat point
[prof, pattr] = build_satlat(prof,pattr);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% REMOVE THIS BEFORE PRODUCTION COMMIT     %%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%% subset rtp for faster debugging
%%%% JUST GRAB THE FIRST 100 OBS
% $$$ fprintf(1, '>>> SUBSETTING PROF FOR DEBUG\n');
% $$$ iTest =(1:1000);
% $$$ prof_sub = prof;
% $$$ prof = rtp_sub_prof(prof_sub, iTest);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Add profile data
model = cfg.model;
fprintf(1, '>>> Add model: %s...', model)

RTIMESHIFTED = false;
if (isfield(cfg,'modelshift') & cfg.modelshift ~= 0)
    RTIMESHIFTED = true;
    fprintf(1, '** Shifting rtime by %d seconds\n', cfg.modelshift)
    rtime = prof.rtime + cfg.modelshift;
    prof.rtime = rtime;
    clear rtime
end

switch model
  case 'ecmwf'
    [prof,head,pattr]  = fill_ecmwf(prof,head,pattr,cfg);
  case 'era'
    [prof,head,pattr]  = fill_era(prof,head,pattr);
  case 'merra'
    [prof,head,pattr]  = fill_merra(prof,head,pattr);
end

if RTIMESHIFTED
    RTIMESHIFTED = false;
    rtime = prof.rtime - cfg.modelshift;
    prof.rtime = rtime;
    clear rtime
end

% rtp now has profile and obs data ==> 5
head.pfields = 5;
[nchan,nobs] = size(prof.robs1);
head.nchan = nchan;
% $$$ head.ngas=2;
fprintf(1, 'Done\n');

% Add landfrac, etc.
fprintf(1, '>>> Running rtpadd_usgs_10dem...');
[head, hattr, prof, pattr] = rtpadd_usgs_10dem(head,hattr,prof,pattr);
fprintf(1, 'Done\n');

% Add Dan Zhou's emissivity and Masuda emis over ocean
% Dan Zhou's one-year climatology for land surface emissivity and
% standard routine for sea surface emissivity
fprintf(1, '>>> Running rtp_add_emis_single...');
[prof,pattr] = rtp_add_emis_single(prof,pattr);
fprintf(1, 'Done\n');


% run klayers
fn_rtp1 = fullfile(sTempPath, ['cris_' sID '_1.rtp']);
fprintf(1, '>>> Writing klayers input temp file %s ...', fn_rtp1);
rtpwrite(fn_rtp1,head,hattr,prof,pattr)
fprintf(1, 'Done\n')
fn_rtp2 = fullfile(sTempPath, ['cris_' sID '_2.rtp']);
unix([cfg.klayers_exec ' fin=' fn_rtp1 ' fout=' fn_rtp2 ' > ' sTempPath ...
      '/klayers_' sID '_stdout'])
fprintf(1, 'Done\n');

% Run sarta
    % *** split fn_rtp3 into 'N' multiple chunks (via rtp_sub_prof like
    % below for clear,site,etc?) make call to external shell script to
    % run 'N' copies of sarta backgrounded
    fprintf(1, '>>> Running sarta... ');
% run driver_sarta_cloud to handle klayers and sarta runs
    sarta_cfg.clear=cfg.clear;
    sarta_cfg.cloud=cfg.cloud;
    sarta_cfg.cumsum=cfg.cumsum;
    sarta_cfg.klayers_code = cfg.klayers_exec;
    sarta_cfg.sartaclear_code = cfg.sartaclr_exec;
    sarta_cfg.sartacloud_code = cfg.sartacld_exec;

    which driver_sarta_cloud_rtp
    prof = driver_sarta_cloud_rtp(head, hattr, prof, pattr, ...
                                  sarta_cfg);

end  % end function




