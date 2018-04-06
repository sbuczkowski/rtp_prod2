function [iflags, wbto, wbtc, wchan] = airs_find_clear(head, prof, iobs2check);
% AIRSFINDCLEAR flag clear AIRS FOVs
%
% Do clear tests for the specified FOV/profile indices and
% return test results as bit flags. 
%
% Input:
%    head - RTP header structure with fields ichan and vchan
%    prof - RTP profiles structure with fields rcalc, robs1, landfrac
%    iobs2check - [1 x ncheck] obs indices to check (likely often all obs
%    i.e. 1:length(prof.rtime))
%
% Output: iflags - [1 x ncheck] bit flags for the following tests: 1 =
%    abs(BTobs-BTcal) at 1232 wn > threshold 2 = cirrus detected 4 =
%    dust/ash detected wbto - [1 x ncheck] BTobs of 1232 or 961 wn
%    window wbtc - [1 x ncheck] BTcal of 1232 or 961 wn window wchan -
%    wavenumber of bto/btc window chan
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
sFuncName = 'airs_find_clear';

% Test channels (wn) (note: must be sorted by ID)
%          1       2       3       4        5        6     7       8        9
ftest =[ 819.312;856.736;912.656;961.060;1043.863;1071.018;1083.364;1092.928;1232.368];

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Find indices of idtest in head.ichan
[indtest, deltas] = matchWN2Ind(ftest, head.vchan);
[~, idtest, ~] = intersect(head.ichan, indtest);

% Find sea and non-sea indices
ncheck = length(iobs2check);
isea = find(prof.landfrac(iobs2check) < 0.02);
inot = setdiff(iobs2check, isea);

% Declare output array
iflags = zeros(1,ncheck);

% Compute BT of test channels
r = prof.robs1(idtest,iobs2check);
ibad = find(r < 1E-5);
r(ibad) = 1E-5;
bto = real(rad2bt(head.vchan(idtest), r));
% REVISITME: ***************************************
% needed until renaming rcalc -> rclr is completed
% (safe to leave in after but, will be unnecessary)
if isfield(prof, 'rcalc')
    r = prof.rcalc(idtest,iobs2check);
elseif isfield(prof, 'rclr')
    r = prof.rclr(idtest, iobs2check);
else
    error(sprintf('>>> %s: prof struct has no clear calcs',sFuncName);
end
% **************************************************
ibad = find(r < 1E-5);
r(ibad) = 1E-5;
btc = real(rad2bt(head.vchan(idtest), r));
clear r ibad

% Test #1 bitvalue=1: window channel dBT 
% REVISITME: ***************************************
% which is preferred? 1232 or 961? Should this be externally
% controllable?
% $$$ ix = 9; % ~1232 wn
ix = 4;  % ~961 wn
% **************************************************
wchan = ftest(ix);
wbto = bto(ix,:);
wbtc = btc(ix,:);
wdbt = wbto - wbtc;
ii = isea( find(wdbt(isea) > 4 | wdbt(isea) < -3) );
iflags(ii) = iflags(ii) + 1;
ii = inot( find(wdbt(inot) > 7 | wdbt(inot) < -7) );
iflags(ii) = iflags(ii) + 1;

% Test #2 bitvalue=2: cirrus
ix820 = 1; % ~820 wn
ix856 = 2; % ~856 wn
ix960 = 4; % ~960 wn
%
dbt960 =  bto(ix960,:) - btc(ix960,:);
dbt820x = bto(ix820,:) - btc(ix820,:) - dbt960;
dbt856x = bto(ix856,:) - btc(ix856,:) - dbt960;
ii = isea( find(dbt820x(isea) < -0.5 & dbt856x(isea) < 0.5*dbt820x(isea)) );
iflags(ii) = iflags(ii) + 2;
ii = inot( find(dbt820x(inot) < -1.0 & dbt856x(inot) < 0.5*dbt820x(inot)) );
iflags(ii) = iflags(ii) + 2;

% Test #3 bitvalue=4: dust/ash
  ix912  = 3; %  ~912 wn
  ix1043 = 5; % ~1043 wn
  ix1071 = 6; % ~1071 wn
  ix1083 = 7; % ~1083 wn
  ix1093 = 8; % ~1093 wn
  %
  % REVISITME: ***************************************
  % CrIS code subtracts off dbt1232 which has been modified to be
  % actually be dbt960. Should this be the window channel used in
  % test 1 above or should it be dbt1232 regardless? For now, going
  % with the sentiment of the CrIS code and making this be wdbt, the
  % dbt of the window channel used in #1, either 1232 or 960
  % **************************************************
  dbt912x  = bto( ix912,:) - btc( ix912,:) - wdbt;
  dbt960x  = bto( ix960,:) - btc( ix960,:) - wdbt;
  dbt1043x = bto(ix1043,:) - btc(ix1043,:) - wdbt;
  dbt1071x = bto(ix1071,:) - btc(ix1071,:) - wdbt;
  dbt1083x = bto(ix1083,:) - btc(ix1083,:) - wdbt;
  dbt1093x = bto(ix1093,:) - btc(ix1093,:) - wdbt;
  ii = isea( find(dbt1083x(isea) < -0.5 & dbt960x(isea)+0.1 < dbt912x(isea)) );
  iflags(ii) = iflags(ii) + 4;
  ii = inot( find(dbt1083x(inot) < -1.0 & dbt960x(inot)+0.1 < dbt912x(inot)) );
  iflags(ii) = iflags(ii) + 4;
%%% end of function %%%
