function runBaselines(varargin)
% Prob convert to official test framework when there are more tests

[dotest,resultsfile,dosave,nrptMV] = myparse(varargin,...
  'dotest',true,...
  'resultsfile','/groups/branson/bransonlab/apt/test/baselines_master_20180507',...
  'dosave',false,...
  'nrptMV',1);

p = fileparts(mfilename('fullpath'));
%p = pwd;

LBLBASE = {'pend'};
lblname = LBLBASE{1};

fprintf(1,'Working on %s\n',lblname);
lObj = Labeler();

% pend only
mfts = MFTSet(...
  MovieIndexSetVariable.AllMov,...
  FrameSetFixed(100:170),...
  FrameDecimationFixed.EveryFrame,...
  TargetSetVariable.AllTgts);

lblm = [lblname '_mv.lbl'];
lObj.projLoad(lblm);

resMV = cell(nrptMV,1);
for irpt=1:nrptMV
  lObj.tracker.init();
  lObj.trackRetrain();
  lObj.track(mfts);
  resMV{irpt} = lObj.tracker.getTrackingResults(MovieIndex(1));
  fprintf(1,'Done MV train/track, repeat %d/%d\n',irpt,nrptMV);
end

resSingVw = cell(1,2);
for ivw=1:2
  lblvw = sprintf('%s_%d.lbl',lblname,ivw);
  lObj.projLoad(lblvw);
  lObj.tracker.init();
  lObj.trackRetrain();
  lObj.track(mfts);
  resSingVw{ivw} = lObj.tracker.getTrackingResults(MovieIndex(1));
  fprintf(1,'Done View %d train/track\n',ivw);
end

if dosave
  fname = sprintf('baselines_%s',datestr(now,'yyyymmddTHHMMSS'));
  save(fname,'resMV','resSingVw');
end

if dotest
  resBL = load(resultsfile,'-mat');
  
  PTILES = [50 90];
  for ivw=1:2
    % Compute "correct answer" as mean of resBL.resMV over repeats.
    % Compute answer spread as dispersion of resBL.resMV over repeats
    nBLrpt = numel(resBL.resMV);
    pTrkRpt = arrayfun(@(x)resBL.resMV{x}(ivw).pTrk,1:nBLrpt,'uni',0);
    pTrkMu = nanmean(cat(4,pTrkRpt{:}),4); % [npt x 2 x ntrkfrm]
    pTrkRptMuErr = cellfun(@(x)lclErr(x,pTrkMu),pTrkRpt,'uni',0); % [npt x ntrkfrm] in each cell
    pTrkRptMeanMuErr = nanmean(cat(3,pTrkRptMuErr{:}),3); % [npt x ntrkfrm];

    % check resMV, 1st repeat only 
    errMV = lclErr(resMV{1}(ivw).pTrk,pTrkMu); % [npt x ntrkfrm]
    errMVnorm = errMV./pTrkRptMeanMuErr;
    errMV = errMV';
    errMVnorm = errMVnorm';
    
    fprintf(1,'\nMultiView, view %d\n',ivw);
    fprintf(1,' Err ptiles %s:\n',mat2str(PTILES));
    disp(prctile(errMV,PTILES));
    fprintf(1,' Normalized err ptiles:\n');
    disp(prctile(errMVnorm,PTILES));    
    
    % check resSingVw
    errSV = lclErr(resSingVw{ivw}.pTrk,pTrkMu); % [npt x ntrkfrm]
    errSVnorm = errSV./pTrkRptMeanMuErr;
    errSV = errSV';
    errSVnorm = errSVnorm';

    fprintf(1,'\nSingleView, view %d\n',ivw);
    fprintf(1,' Err ptiles %s:\n',mat2str(PTILES));
    disp(prctile(errSV,PTILES));
    fprintf(1,' Normalized err ptiles:\n');
    disp(prctile(errSVnorm,PTILES));
  end
end

function err = lclErr(pTrk1,pTrk2)
d = pTrk1-pTrk2;
err = squeeze(sqrt(sum(d.^2,2)));
