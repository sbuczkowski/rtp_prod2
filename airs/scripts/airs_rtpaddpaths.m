%*************************************************
% Execute user-defined paths *********************
REPOBASEPATH = '/home/sbuczko1/git/';
% $$$ REPOBASEPATH = '/asl/packages/';

% rtp_prod2
addpath(sprintf('%s/rtp_prod2_DEV/util', REPOBASEPATH));
addpath(sprintf('%s/rtp_prod2_DEV/grib', REPOBASEPATH));
addpath(sprintf('%s/rtp_prod2_DEV/emis', REPOBASEPATH));
addpath(genpath(sprintf('%s/rtp_prod2_DEV/airs', REPOBASEPATH)));

% swutils (will move under matlib soon)
addpath(sprintf('%s/swutils', REPOBASEPATH));

% matlib
addpath(sprintf('%s/matlib/clouds/sarta', REPOBASEPATH));  % driver_cloudy_sarta
addpath(sprintf('%s/matlib/rtptools', REPOBASEPATH));   % for cat_rtp

addpath /asl/matlib/aslutil
addpath /asl/matlib/time

% Chris' fill_?? routines                                                                        
addpath /home/chepplew/gitLib/rtp_fill_gases/
%*************************************************
