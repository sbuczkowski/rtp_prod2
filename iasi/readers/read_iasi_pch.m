function [head, hattr, prof, pattr] = read_iasi_pch(granfilepath, cfg)

    mfilepath = mfilename('fullpath');
    mp = fileparts(mfilepath);
    
    head = struct;
    hattr = {};
    prof = struct;
    pattr = {};


    PCCBasisFile1 = fullfile(cfg.pc_basedir, h5readatt(granfilepath, '/band_1', 'PCC_BasisFile'));
    PCCBasisFile2 = fullfile(cfg.pc_basedir, h5readatt(granfilepath, '/band_2', 'PCC_BasisFile'));
    PCCBasisFile3 = fullfile(cfg.pc_basedir, h5readatt(granfilepath, '/band_3', 'PCC_BasisFile'));

    R1 = h5read(PCCBasisFile1, '/ReconstructionOperator');
    R2 = h5read(PCCBasisFile2, '/ReconstructionOperator');
    R3 = h5read(PCCBasisFile3, '/ReconstructionOperator');

    scale_factor = 0.5; % should read this from granfilepath in case things change
    p1 = scale_factor * double(h5read(granfilepath, '/band_1/p'));
    p2 = scale_factor * double(h5read(granfilepath, '/band_2/p'));
    p3 = scale_factor * double(h5read(granfilepath, '/band_3/p'));

    p_local1 = scale_factor * double(h5read(granfilepath, '/band_1/p_local'));
    p_local2 = scale_factor * double(h5read(granfilepath, '/band_2/p_local'));
    p_local3 = scale_factor * double(h5read(granfilepath, '/band_3/p_local'));

    R_local1 = h5read(granfilepath, '/band_1/R_local');
    R_local2 = h5read(granfilepath, '/band_2/R_local');
    R_local3 = h5read(granfilepath, '/band_3/R_local');

    yl1 = pagemtimes(R1,p1) + pagemtimes(R_local1,p_local1);
    yl2 = pagemtimes(R2,p2) + pagemtimes(R_local2,p_local2);
    yl3 = pagemtimes(R3,p3) + pagemtimes(R_local3,p_local3);


    unit_conversion = 1e5; % pch is Wm-2sr-1 (m-1)-1, raw files are mWm-2sr-1 (cm-1)-1
    yl = cat(1, yl1, yl2, yl3);
    prof.robs1 = reshape(yl, 8461,120*23)*unit_conversion;
    clear yl* p1 p2 p3 p_local* R* P*

    % read Lat/lon
    temp = h5read(granfile, '/Latitude');
    [nfovs, nscans] = size(temp);
    prof.rlat = reshape(temp, 1, nfovs*nscans);
    temp = h5read(granfile, '/Longitude');
    [nfovs, nscans] = size(temp);
    prof.rlon = reshape(temp, 1, nfovs*nscans);

    % read obs time
    % obs time is not currently stored in PCH granules. Granule start
    % and stop times are encoded in the granule filename. According to
    % the product guide, the IASI scan take 6.486 seconds with a 1.514
    % second off-targe scanset. So, first obs in each scanline should
    % be 8 seconds apart with the 30 FORs within scanline being 0.2162
    % seconds apart. In practice, from looking at uncompressed files
    % Time2000 fields, time between FORs is variable running 0.2140 to
    % 0.2190s in one sample. Time gap between FOR 30 and the start of
    % the next scan is 1.7310s in the same sample granule.

    % Filename encodes start and stop times for granule
    % in fields 5 and 6, respectively.
    % IASI_PCH_1C_M03_20230331114153Z_20230331114456Z_N_O_20230331123048Z.h5

    [inpath, granfile, ext] = fileparts(granfilepath);
    C = strsplit(granfile,'_');
    platform = C{4};
    tstart = C{5};
    tend = C{6};

    
    % Build out rtp structs **************************
    nchan = size(prof.robs1,1);
    % following line loads arrays 'v/ichan' 
    load(fullfile(mp, '../static/iasi_freq'));

    % Header 
    head = struct;
    head.pfields = 4;  % robs1, no calcs in file
    head.ptype = 0;    % levels
    head.ngas = 0;
    head.nchan = length(ichan); 
    head.ichan = ichan; 
    head.vchan = vchan; 
    head.vcmax = max(head.vchan);
    head.vcmin = min(head.vchan);

    % hattr
    hattr={ {'header' 'pltfid' platform}, ...
            {'header' 'instid' 'IASI'}};

    % profile attribute changes for airicrad
    pattr = set_attr(pattr, 'robs1', inpath);
    pattr = set_attr(pattr, 'rtime', '*ESTIMATED* TAI:1958');

    %*************************************************

end

