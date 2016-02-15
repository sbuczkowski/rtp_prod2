function create_cris_ccast_lowres_rtp(fnCrisInput, fnCrisOutput)
% PROCESS_CRIS_LOWRES process one granule of CrIS data
%
% Process a single CrIS .mat granule file.

%set_process_dirs;

fprintf(1, '>> Running create_cris_ccast_lowres_rtp for input: %s\n', ...
        fnCrisInput);

% use fnCrisOutput to generate year and doy strings
% fnCrisOutput will be of the form rtp_d<YYYMMDD>_t<granule time>
cris_yearstr = fnCrisOutput(6:9);
month = str2num(fnCrisOutput(10:11));
day = str2num(fnCrisOutput(12:13));
dt = datetime(str2num(cris_yearstr), month, day);
dt.Format = 'DDD';
cris_doystr = char(dt);

klayers_exec = '/asl/packages/klayersV205/BinV201/klayers_airs_wetwater';
sarta_exec  = ['/asl/packages/sartaV108/BinV201/' ...
               'sarta_crisg4_nov09_wcon_nte'];  %% lowres

addpath(genpath('/asl/matlib'));
% Need these two paths to use iasi2cris.m in iasi_decon
addpath /asl/packages/iasi_decon
addpath /asl/packages/ccast/source
addpath /home/sbuczko1/git/rtp_prod2/cris
addpath /home/sbuczko1/git/rtp_prod2/util
addpath /home/sbuczko1/git/rtp_prod2/emis
addpath /home/sbuczko1/git/rtp_prod2/grib

[sID, sTempPath] = genscratchpath();
sID = getenv('SLURM_ARRAY_TASK_ID');
nguard = 2;  % number of guard channels


% Load up rtp
try
    [head, hattr, prof, pattr] = ccast2rtp(fnCrisInput, nguard);
catch
    fprintf(2, '>>> ERROR: ccast2rtp failed for %s\n', ...
            fnCrisInput);
    return;
end

temp = size(head.ichan)
if temp(2) > 1
    head.ichan = head.ichan';
end
temp = size(head.vchan)
if temp(2) > 1
    head.vchan = head.vchan';
end

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

% Need this later
ichan_ccast = head.ichan;

% Add profile data
fprintf(1, '>>> Running fill_era... ');
[prof,head]=fill_era(prof,head);
fprintf(1, 'Done\n');

% $$$ [prof,head]=fill_ecmwf(prof,head);
% rtp now has profile and obs data ==> 5
head.pfields = 5;
[nchan,nobs] = size(prof.robs1);
head.nchan = nchan;
head.ngas=2;


% Add landfrac, etc.
fprintf(1, '>>> Running usgs_10dem... ');
[head, hattr, prof, pattr] = rtpadd_usgs_10dem(head,hattr,prof, ...
                                               pattr);
fprintf(1, 'Done\n');

% Add Dan Zhou's emissivity and Masuda emis over ocean
% Dan Zhou's one-year climatology for land surface emissivity and
% standard routine for sea surface emissivity
% $$$ fprintf(1, '>>> Running rtp_ad_emis...');
% $$$ [prof,pattr] = rtp_add_emis(prof,pattr);
% $$$ fprintf(1, 'Done\n');
fprintf(1, '>>> Running add_emis... ');
[prof,pattr] = rtp_add_emis_single(prof,pattr);
fprintf(1, 'Done\n');

% Subset for quicker debugging
% prof = rtp_sub_prof(prof, 1:10:length(prof.rlat));

% run Sergio's subsetting routine
px = prof;
% $$$ px = rmfield(prof,'rcalc');
hx = head; hx.pfields = 5;

% $$$ prof = uniform_clear_template_lowANDhires_HP(hx,hattr,px,pattr); %% super (if it works)
% for redo of random subset. There are some issues with Sergio's
% code that we are trying to find a way around. THIS WILL NOT WORK
% FOR OTHER SUBSETS
fprintf(1, '>>> Running hha_lat_subsample... ');
[irand,irand2] = hha_lat_subsample_equal_area2_cris_hires(head, prof);
if numel(irand) == 0
    fprintf(2, ['>>> ERROR : No random obs returned. Skipping to ' ...
                'next granule.\n'])
    return;
end

prof = rtp_sub_prof(prof,irand)
fprintf(1, 'Done\n');

% run klayers
fn_rtp1 = fullfile(sTempPath, ['cris_' sID '_1.rtp']);
fprintf(1, '>>> Writing klayers input temp file %s ...', fn_rtp1);
rtpwrite(fn_rtp1,head,hattr,prof,pattr)
fprintf(1, 'Done\n')
fn_rtp2 = fullfile(sTempPath, ['cris_' sID '_2.rtp']);
run_klayers=[klayers_exec ' fin=' fn_rtp1 ' fout=' fn_rtp2 ' > ' sTempPath ...
             '/klayers_' sID '_stdout']
fprintf(1, '>>> Running klayers: %s ...', run_klayers);
unix([klayers_exec ' fin=' fn_rtp1 ' fout=' fn_rtp2 ' > ' sTempPath ...
      '/klayers_' sID '_stdout'])
fprintf(1, 'Done\n');
fprintf(1, '>>> Reading klayers output... ');
[head, hattr, prof, pattr] = rtpread(fn_rtp2);
fprintf(1, 'Done\n');

% Run sarta
% *** split fn_rtp3 into 'N' multiple chunks (via rtp_sub_prof like
% below for clear,site,etc?) make call to external shell script to
% run 'N' copies of sarta backgrounded
fn_rtp3 = fullfile(sTempPath, ['cris_' sID '_3.rtp']);
run_sarta = [sarta_exec ' fin=' fn_rtp2 ' fout=' fn_rtp3 ' > ' ...
             sTempPath '/sarta_' sID '_stdout.txt'];
fprintf(1, '>>> Running sarta: %s ...', run_sarta);
unix(run_sarta);
fprintf(1, 'Done\n');

% Read in new rcalcs and insert into origin prof field
% $$$ stFileInfo = dir(fn_rtp3);
% $$$ fprintf(1, ['*************\n>>> Reading fn_rtp3:\n\tName:\t%s\n\tSize ' ...
% $$$             '(GB):\t%f\n*************\n'], stFileInfo.name, stFileInfo.bytes/1.0e9);
fprintf(1, '>>> Reading sarta output... ');
[h,ha,p,pa] = rtpread(fn_rtp3);
fprintf(1, 'Done\n');

% Go get output from klayers, which is what we want except for rcalc
% $$$ [head, hattr, prof, pattr] = rtpread(fn_rtp2);
% Insert rcalc for CrIS derived from IASI SARTA
prof.rcalc = p.rcalc;
head.pfields = 7;

% output rtp splitting from airxbcal processing
% Subset into four types and save separately
% $$$ iclear = find(prof.iudef(1,:) == 1);
% $$$ isite  = find(prof.iudef(1,:) == 2);
% $$$ idcc   = find(prof.iudef(1,:) == 4);
% $$$ irand  = find(prof.iudef(1,:) == 8);
irand = 1;

% $$$ prof_clear = rtp_sub_prof(prof,iclear);
% $$$ prof_site  = rtp_sub_prof(prof,isite);
% $$$ prof_dcc   = rtp_sub_prof(prof,idcc);
% $$$ prof_rand  = rtp_sub_prof(prof,irand);
prof_rand = prof;

rtp_out_fn_head = fnCrisOutput;
if irand ~= 0
    rtp_out_fn = [rtp_out_fn_head, '_rand.rtp'];
    rtp_outname = fullfile(sTempPath,  rtp_out_fn);
    fprintf(1, '>>> writing output rtp file %s to local scratch... ', rtp_outname);
    try
        rtpwrite(rtp_outname,head,hattr,prof_rand,pattr);
    catch
        fprintf(2, '>>> ERROR: rtpwrite of scratch output failed\n');
        return;
    end
    fprintf(1, 'Done\n');
    
end
% Make directory if needed
% cris lowres data will be stored in
% /asl/data/rtp_cris_ccast_lowres/{clear,dcc,site,random}/<year>/<doy>
%
asType = {'clear', 'site', 'dcc', 'random'};
cris_out_dir = '/asl/data/rtp_cris_ccast_lowres';
rtp_outname2 = fullfile(cris_out_dir, char(asType(4)),cris_yearstr, ...
                        cris_doystr,  rtp_out_fn);
for i = 4:length(asType)
% check for existence of output path and create it if necessary. This may become a source
% for filesystem collisions once we are running under slurm.
    sPath = fullfile(cris_out_dir,char(asType(i)),cris_yearstr,cris_doystr);
    if exist(sPath) == 0
        mkdir(sPath);
    end
end
fprintf(1, '>>> moving scratch outputfile to lustre ...\n');
fprintf(1, '\t %s --> %s\n', rtp_outname, rtp_outname2);
movefile(rtp_outname, rtp_outname2);
fprintf(1, 'Done\n');
% $$$

% Now save the four types of cris files
% if no profiles are captured in a subset, do not output a file
% $$$ if iclear ~= 0
% $$$     rtp_out_fn = [rtp_out_fn_head, '_clear.rtp'];
% $$$     rtp_outname = fullfile(cris_out_dir,char(asType(1)),cris_yearstr,  cris_doystr, rtp_out_fn);
% $$$     rtpwrite(rtp_outname,head,hattr,prof_clear,pattr);
% $$$ end
% $$$ 
% $$$ if isite ~= 0
% $$$     rtp_out_fn = [rtp_out_fn_head, '_site.rtp'];
% $$$     rtp_outname = fullfile(cris_out_dir, char(asType(2)),cris_yearstr, cris_doystr,  rtp_out_fn);
% $$$     rtpwrite(rtp_outname,head,hattr,prof_site,pattr);
% $$$ end
% $$$ 
% $$$ if idcc ~= 0
% $$$     rtp_out_fn = [rtp_out_fn_head, '_dcc.rtp'];
% $$$     rtp_outname = fullfile(cris_out_dir, char(asType(3)),cris_yearstr, cris_doystr,  rtp_out_fn);
% $$$     rtpwrite(rtp_outname,head,hattr,prof_dcc,pattr);
% $$$ end

fprintf(1, 'Done\n');