function [head, hattr, prof, pattr] = create_cris_ccast_hires_clear_gran_rtp(fnCrisInput, cfg)
% PROCESS_CRIS_HIRES process one granule of CrIS data
%
% Process a single CrIS .mat granule file.

fprintf(1, '>> Running create_cris_ccast_hires_rtp for input: %s\n', ...
        fnCrisInput);


% read in configuration options from 'cfg'
klayers_exec = '/asl/packages/klayersV205/BinV201/klayers_airs_wetwater';
if isfield(cfg, 'klayers_exec')
    klayers_exec = cfg.klayers_exec;
end

sarta_exec  = ['/asl/packages/sartaV108/BinV201/' ...
               'sarta_iasi_may09_wcon_nte'];
if isfield(cfg, 'sarta_exec')
    sarta_exec = cfg.sarta_exec;
end
nguard = 2;  % number of guard channels
if isfield(cfg, 'nguard')
    nguard = cfg.nguard;
end
nsarta = 4;  % number of sarta guard channels
if isfield(cfg, 'nsarta')
    nsarta = cfg.nsarta;
end
% check for validity of guard channel specifications
if nguard > nsarta
    fprintf(2, ['*** Too many guard channels requested/specified ' ...
                '(nguard/nsarta = %d/%d)***\n'], nguard, nsarta);
    return
end
    

addpath(genpath('/asl/matlib'));
% Need these two paths to use iasi2cris.m in iasi_decon
addpath /asl/packages/iasi_decon
addpath /asl/packages/ccast/source
addpath /asl/packages/rtp_prod2/cris;  % uniform_clear_template_...
% addpath /asl/packages/ccast/motmsc/rtp_sarta; % ccast2rtp, cris_[iv]chan
addpath /home/motteler/cris/ccast/motmsc/rtp_sarta; % ccast2rtp, cris_[iv]chan
% $$$ addpath /asl/packages/rtp_prod2/grib;  % fill_era/ecmwf
addpath /home/sbuczko1/git/rtp_prod2/grib
addpath /asl/packages/rtp_prod2/emis;  % add_emis
addpath /asl/packages/rtp_prod2/util;  % rtpread/write
addpath ../util

[sID, sTempPath] = genscratchpath();

cfg.sID = sID;
cfg.sTempPath = sTempPath;

% Load up rtp
[head, hattr, prof, pattr] = ccast2rtp(fnCrisInput, nguard, nsarta);
%%** second parameter sets up the use of 4 CrIS guard
%%channels. Looking at head.ichan and head.vchan shows some
%%similarity to the cris channel description in
%%https://hyperearth.wordpress.com/2013/07/09/cris-rtp-formats/, at
%%least for the first set of guard channels

% check that [iv]chan are column vectors
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

% build sub-satellite lat point
[prof, pattr] = build_satlat(prof, pattr);

% Add profile data
switch cfg.model
  case 'ecmwf'
    [prof,head,pattr]=fill_ecmwf(prof,head,pattr,cfg);
  case 'era'
    [prof,head,pattr]=fill_era(prof,head,pattr);
  case 'merra'
    [prof,head,pattr]=fill_merra(prof,head,pattr);    
end

% rtp now has profile and obs data ==> 5
head.pfields = 5;
[nchan,nobs] = size(prof.robs1);
head.nchan = nchan;
head.ngas=2;


% Add landfrac, etc.
[head, hattr, prof, pattr] = rtpadd_usgs_10dem(head,hattr,prof,pattr);

% Add Dan Zhou's emissivity and Masuda emis over ocean
% Dan Zhou's one-year climatology for land surface emissivity and
% standard routine for sea surface emissivity
fprintf(1, '>>> Running rtp_ad_emis...');
[prof,pattr] = rtp_add_emis_single(prof,pattr);
fprintf(1, 'Done\n');

% run Sergio's subsetting routine
fprintf(1, '>> Building basic filtering flags (uniform_clear_template...)\n');
% $$$ % $$$ px = rmfield(prof,'rcalc');
% $$$ hx = head; hx.pfields = 5;
fprintf(1, '>>> NGAS = %d\n', head.ngas);
px = uniform_clear_template_lowANDhires_HP(head,hattr,prof,pattr); %% super (if it works)

% subset out the clear
% output rtp splitting from airxbcal processing
% Subset into four types and save separately
iclear = find(px.iudef(1,:) == 1);
prof = rtp_sub_prof(px,iclear);
clear px;

% run klayers
fn_rtp1 = fullfile(sTempPath, ['cris_' sID '_1.rtp']);
rtpwrite(fn_rtp1,head,hattr,prof,pattr);
fn_rtp2 = fullfile(sTempPath, ['cris_' sID '_2.rtp']);
unix([klayers_exec ' fin=' fn_rtp1 ' fout=' fn_rtp2 ' > ' sTempPath '/klayers_stdout'])

% scale gas concentrations, if requested in config
if isfield(cfg, 'scaleco2') | isfield(cfg, 'scalech4')
    % read in klayers output
    [hh,hha,pp,ppa] = rtpread(fn_rtp2);
    delete fn_rtp2
    if isfield(cfg, 'scaleco2')
        pp.gas_2 = pp.gas_2 * cfg.scaleco2;
        pattr{end+1} = {'profiles' 'scaleCO2' sprintf('%f', cfg.scaleco2)};
    end
    if isfield(cfg, 'scalech4')
        pp.gas_6 = pp.gas_6 * cfg.scalech4;
        pattr{end+1} = {'profiles' 'scaleCH4' sprintf('%f', cfg.scalech4)};        
    end
    rtpwrite(fn_rtp2,hh,hha,pp,ppa)
end
    
% run sarta

if strcmp('csarta', cfg.rta)
    fprintf(1, '>>> Running CrIS sarta... ');
    fn_rtp3 = fullfile(sTempPath, [sID '_3.rtp']);
    sarta_run = [sarta_exec ' fin=' fn_rtp2 ' fout=' fn_rtp3 ...
                 ' > ' sTempPath '/sartaout.txt'];
    unix(sarta_run);

    % read in sarta results to capture rcalc
    [~,~,p,~] = rtpread(fn_rtp3);
    prof.rclr = p.rcalc;
    clear p;
    fprintf(1, 'Done\n');
else if strcmp('isarta', cfg.rta)
        fprintf(1, '>>> Running IASI sarta... ');
        cfg.fn_rtp2 = fn_rtp2;
        [hh,hha,pp,ppa] = rtpread(fn_rtp2);
        [~, ~, p, ~] = run_sarta_iasi(hh,hha,pp,ppa,cfg);
        prof.rclr = p.rclr;
        fprintf(1, 'Done\n');
end
end  % end run sarta 
    
