%%

%gtfile = '/nrs/branson/mayank/apt_cache/alice_view0_time.mat';

exptype = 'RFView1';
cprdir = '/groups/branson/bransonlab/apt/experiments/res/cprgt20190407';
codedir = fileparts(mfilename('fullpath'));
savedir = '/groups/branson/bransonlab/apt/experiments/res/gt/20190523';

if ~exist(savedir,'dir'),
  mkdir(savedir);
end
dosavefig = true;

%% parameters

gtimdata = [];

nets = {'openpose','leap','deeplabcut','unet','resnet_unet','mdn','cpropt'};
legendnames = {'OpenPose','LEAP','DeepLabCut','U-net','Res-U-net','MDN','CPR'};
nnets = numel(nets);
colors = [
  0         0.4470    0.7410
  0.4660    0.6740    0.1880
  0.8500    0.3250    0.0980
  0.9290    0.6940    0.1250
  0.6350    0.0780    0.1840
  0.4940    0.1840    0.5560
  0.3010    0.7450    0.9330
  ];
prcs = [50,75,90,95,97];

idxnet = [1 2 3 7 4 5 6];
nets = nets(idxnet);
colors = colors(idxnet,:);
legendnames = legendnames(idxnet);
vwi = 1;
doAlignCoordSystem = false;
annoterrfile = '';


switch exptype,
  case {'SHView0','SHView1'}
    if strcmp(exptype,'SHView0'),
      %gtfile_trainsize = '/nrs/branson/mayank/apt_cache/stephen_view0_trainsize.mat';
      gtfile_trainsize_cpr = fullfile(cprdir,'outputFINAL/stephen_view0_trainsize_withcpr.mat');
      gtfile_traintime_cpr = '';
      gtfile_trainsize = '/nrs/branson/mayank/apt_cache/stephen_view0_trainsize.mat';
      gtfile_traintime = '/nrs/branson/mayank/apt_cache/stephen_view0_time.mat';
      vwi = 1;
    else
      %gtfile_trainsize = '/nrs/branson/mayank/apt_cache/stephen_view1_trainsize.mat';
      gtfile_trainsize_cpr = fullfile(cprdir,'outputFINAL/stephen_view1_trainsize_withcpr.mat');
      gtfile_traintime_cpr = '';
      gtfile_trainsize = '/nrs/branson/mayank/apt_cache/stephen_view1_trainsize.mat';
      gtfile_traintime = '/nrs/branson/mayank/apt_cache/stephen_view1_time.mat';
      vwi = 2;
    end
    condinfofile = '/groups/branson/home/bransonk/tracking/code/APT/SHTrainGTInfo20190416.mat';
    gtdata_size = load(gtfile_trainsize);
    nlabels = size(gtdata_size.(nets{end}){end}.labels,1);
    npts = size(gtdata_size.(nets{end}){end}.labels,2);
    
    incondinfo = load(condinfofile);
    conddata = struct;
    % conditions:
    % enriched + activation
    % not enriched + activation
    % not activation
    % data types:
    % train
    % not train
    conddata.data_cond = ones(nlabels,1);
    conddata.data_cond(incondinfo.gtinfo.istrain==1) = 1;
    conddata.data_cond(incondinfo.gtinfo.istrain==0) = 2;
    datatypes = {'same fly',1
      'different fly',2
      'all',[1,2]};

    conddata.label_cond = ones(nlabels,1);
    conddata.label_cond(~incondinfo.gtinfo.isactivation) = 1;
    conddata.label_cond(incondinfo.gtinfo.isactivation&~incondinfo.gtinfo.isenriched) = 2;
    conddata.label_cond(incondinfo.gtinfo.isactivation&incondinfo.gtinfo.isenriched) = 3;
    labeltypes = {'no activation',1
      'activation, not enriched',2
      'enriched activation',3
      'activation',[2,3]
      'all',[1,2,3]};
    pttypes = {'L. antenna tip',1
      'R. antenna tip',2
      'L. antenna base',3
      'R. antenna base',4
      'Proboscis roof',5};
%     labeltypes = {'all',1};
%     datatypes = {'all',1};
    maxerr = 60;
    lblfile = '/groups/branson/home/bransonk/tracking/code/APT/sh_trn4523_gtcomplete_cacheddata_bestPrms20180920_retrain20180920T123534_withGTres_mdn20190214_skeledges.lbl';
    freezeInfo = struct;
    freezeInfo.iMov = 502;
    freezeInfo.iTgt = 1;
    freezeInfo.frm = 746;
    doplotoverx = true;
    gtimdata = struct;
    gtimdata.ppdata = incondinfo.ppdata;
    gtimdata.tblPGT = incondinfo.tblPGT;
    
  case 'FlyBubble'
    %gtfile_trainsize = '/nrs/branson/mayank/apt_cache/alice_view0_trainsize.mat';
    gtfile_trainsize_cpr = fullfile(cprdir,'outputFINAL/alice_view0_trainsize_withcpr.mat');
    gtfile_trainsize = '/nrs/branson/mayank/apt_cache/alice_view0_trainsize.mat';
    %gtfile_traintime = '/nrs/branson/mayank/apt_cache/alice_view0_time.mat';
    gtfile_traintime = '/nrs/branson/mayank/apt_cache/alice_view0_time.mat';
    gtfile_traintime_cpr = '';
    condinfofile = '/nrs/branson/mayank/apt_cache/multitarget_bubble/multitarget_bubble_expandedbehavior_20180425_condinfo.mat';
    gtimagefile = '/groups/branson/home/bransonk/tracking/code/APT/FlyBubbleGTData20190524.mat';
    gtimdata = load(gtimagefile);
    conddata = load(condinfofile);

    pttypes = {'head',[1,2,3]
      'body',[4,5,6,7]
      'middle leg joint 1',[8,10]
      'middle leg joint 2',[9,11]
      'front leg tarsi',[12,17]
      'middle leg tarsi',[13,16]
      'back leg tarsi',[14,15]};
    labeltypes = {'moving',1
      'grooming',2
      'close',3
      'all',[1,2,3]};
    datatypes = {'same fly',1
      'same genotype',2
      'different genotype',3
      'all',[1,2,3]};
    lblfile = '/groups/branson/home/bransonk/tracking/code/APT/multitarget_bubble_expandedbehavior_20180425_FxdErrs_OptoParams20181126_mdn20190214_skeledges.lbl';
    maxerr = 30;
    doplotoverx = true;
    gtdata_size = load(gtfile_trainsize);
    npts = size(gtdata_size.(nets{end}){end}.labels,2);
    annoterrfile = 'AnnotErrData20190614.mat';

  case {'RFView0','RFView1'}
    if strcmp(exptype,'RFView0'),
      %gtfile_trainsize = '/nrs/branson/mayank/apt_cache/stephen_view0_trainsize.mat';
      gtfile_trainsize_cpr = '/groups/branson/bransonlab/apt/experiments/res/cpr_xv_20190504/romn/out/xv_romnproj_alcpreasyprms_tblcvi_romn_split_romn_20190515T173224.mat';%fullfile(cprdir,'outputFINAL/stephen_view0_trainsize_withcpr.mat');
      gtfile_traintime_cpr = '';
      gtfile_trainsize = '/nrs/branson/mayank/apt_cache/romain_view0_cv.mat';
      gtfile_traintime = '';
      vwi = 1;
    else
      %gtfile_trainsize = '/nrs/branson/mayank/apt_cache/stephen_view1_trainsize.mat';
      gtfile_trainsize_cpr = '/groups/branson/bransonlab/apt/experiments/res/cpr_xv_20190504/romn/out/xv_romnproj_alcpreasyprms_tblcvi_romn_split_romn_20190515T173224.mat';%fullfile(cprdir,'outputFINAL/stephen_view0_trainsize_withcpr.mat');
      gtfile_trainsize = '/nrs/branson/mayank/apt_cache/romain_view1_cv.mat';
      gtfile_traintime = '';
      vwi = 2;
    end
    condinfofile = '';
    gtdata_size = load(gtfile_trainsize);
    nlabels = size(gtdata_size.(nets{end}){end}.labels,1);
    npts = size(gtdata_size.(nets{end}){end}.labels,2);

    conddata = [];
    % conditions:
    % enriched + activation
    % not enriched + activation
    % not activation
    % data types:
    % train
    % not train
    labeltypes = {};
    datatypes = {};
    
    
%     pttypes = {'L. antenna tip',1
%       'R. antenna tip',2
%       'L. antenna base',3
%       'R. antenna base',4
%       'Proboscis roof',5};
%     labeltypes = {'all',1};
%     datatypes = {'all',1};
    maxerr = 100;
    lblfile = '/groups/branson/bransonlab/apt/experiments/data/romainTrackNov18_updateDec06_al_portable_mdn60k_openposewking_newmacro.lbl';
    %lblfile = '/groups/branson/bransonlab/apt/experiments/res/romain_viewpref_3dpostproc_20190522/romainTrackNov18_al_portable_mp4s_withExpTriResMovs134_20190522.lbl';
    gtimagefile = '/groups/branson/home/bransonk/tracking/code/APT/RomainTrainCVInfo20190419.mat';
    freezeInfo = struct;
    freezeInfo.iMov = 1;
    freezeInfo.iTgt = 1;
    freezeInfo.frm = 302;
    freezeInfo.clim = [0,192];
    doplotoverx = false;
    gtimdata = load(gtimagefile);
    
    pttypes = {'abdomen',19
      'front leg joint 1',[13,16]
      'front leg joint 2',[7,10]
      'front leg tarsi',[1,4]
      'middle leg joint 1',[14,17]
      'middle leg joint 2',[8,11]
      'middle leg tarsi',[2,5]
      'back leg joint 1',[15,18]
      'back leg joint 2',[9,12]
      'back leg tarsi',[3,6]};
    
  case 'Larva',
    
    gtfile_trainsize_cpr = '/groups/branson/bransonlab/apt/experiments/res/cpr_xv_20190504/larv/out/xv_Larva94A04_CM_tbltrn_larv_split_larv_prm_larv_ar_20190515T093243.mat';
    gtfile_trainsize = '/nrs/branson/mayank/apt_cache/larva_view0_cv.mat';
    gtfile_traintime = '';
    gtimagefile = '/groups/branson/home/bransonk/tracking/code/APT/LarvaTrainCVInfo20190419.mat';
    gtdata_size = load(gtfile_trainsize);
    nlabels = size(gtdata_size.(nets{end}){end}.labels,1);

    conddata = [];
    % conditions:
    % enriched + activation
    % not enriched + activation
    % not activation
    % data types:
    % train
    % not train
    labeltypes = {};
    datatypes = {};
    pttypes = {'outside',[1:2:13,16:2:28]
      'inside',[2:2:14,15:2:27]};
%     pttypes = {'L. antenna tip',1
%       'R. antenna tip',2
%       'L. antenna base',3
%       'R. antenna base',4
%       'Proboscis roof',5};
%     labeltypes = {'all',1};
%     datatypes = {'all',1};
    maxerr = [];
    gtimdata = load(gtimagefile);
    
    lblfile = '/groups/branson/bransonlab/larvalmuscle_2018/APT_Projects/Larva94A04_CM_fixedmovies.lbl';
    freezeInfo = struct;
    freezeInfo.iMov = 4;
    freezeInfo.iTgt = 1;
    freezeInfo.frm = 5;
    freezeInfo.axes_curr.XLim = [745,1584];
    freezeInfo.axes_curr.YLim = [514,1353];
    doplotoverx = false;
    
  case 'Roian'
    %gtfile_trainsize = '/nrs/branson/mayank/apt_cache/stephen_view0_trainsize.mat';
    gtfile_trainsize_cpr = '/groups/branson/bransonlab/apt/experiments/res/cpr_xv_20190504/sere/out/xv_sere_al_cprparamsbigger_20190514_tblcvi_sere_split_sere_20190515T094434.mat';
    gtfile_traintime_cpr = '';
    gtfile_trainsize = '/nrs/branson/mayank/apt_cache/roian_view0_cv.mat';
    gtfile_traintime = '';
    vwi = 1;
    condinfofile = '';
    gtdata_size = load(gtfile_trainsize);
    nlabels = size(gtdata_size.(nets{end}){end}.labels,1);
    npts = size(gtdata_size.(nets{end}){end}.labels,2);

    conddata = [];
    % conditions:
    % enriched + activation
    % not enriched + activation
    % not activation
    % data types:
    % train
    % not train
    labeltypes = {};
    datatypes = {};
%     pttypes = {'L. antenna tip',1
%       'R. antenna tip',2
%       'L. antenna base',3
%       'R. antenna base',4
%       'Proboscis roof',5};
%     labeltypes = {'all',1};
%     datatypes = {'all',1};
    maxerr = 100;
    lblfile = '/groups/branson/bransonlab/apt/experiments/data/roian_apt.lbl';
    gtimagefile = '/groups/branson/home/bransonk/tracking/code/APT/RoianTrainCVInfo20190420.mat';
    freezeInfo = struct;
    freezeInfo.iMov = 1;
    freezeInfo.iTgt = 1;
    freezeInfo.frm = 1101;
    doplotoverx = false;
    gtimdata = load(gtimagefile);
    
    pttypes = {'nose',1
      'tail',2
      'ear',[3,4]};
    
  case {'BSView0x','BSView1x','BSView2x'}
    if strcmp(exptype,'BSView0x'),
      gtfile_trainsize_cpr = '/groups/branson/bransonlab/apt/experiments/res/cpr_xv_20190504/brit/out/xv_wheel_rig_tracker_DEEP_cam0_tbltrn_brit_vw1_split_brit_vw1_prm_brit_al_20190515T184617.mat';
      gtfile_traintime_cpr = '';
      gtfile_trainsize = '/nrs/branson/mayank/apt_cache/brit0_view0_cv.mat';
      gtfile_traintime = '';
      vwi = 1;
      lblfile = '/groups/branson/bransonlab/apt/experiments/data/wheel_rig_tracker_DEEP_cam0.lbl';
      pttypes = {'Front foot',[1,2]
        'Back foot',[3,4]
        'Tail',5};
    elseif strcmp(exptype,'BSView1x'),
      gtfile_trainsize_cpr = '/groups/branson/bransonlab/apt/experiments/res/cpr_xv_20190504/brit/out/xv_wheel_rig_tracker_DEEP_cam1_tbltrn_brit_vw2_split_brit_vw2_prm_brit_al_20190515T184622.mat';
      gtfile_traintime_cpr = '';
      gtfile_trainsize = '/nrs/branson/mayank/apt_cache/brit1_view0_cv.mat';
      gtfile_traintime = '';
      vwi = 1;
      lblfile = '/groups/branson/bransonlab/apt/experiments/data/wheel_rig_tracker_DEEP_cam1.lbl';
      pttypes = {'Front foot',[1,2]};
    else
      gtfile_trainsize_cpr = '/groups/branson/bransonlab/apt/experiments/res/cpr_xv_20190504/brit/out/xv_wheel_rig_tracker_DEEP_cam2_tbltrn_brit_vw3_split_brit_vw3_prm_brit_al_20190515T184819.mat';
      gtfile_traintime_cpr = '';
      gtfile_trainsize = '/nrs/branson/mayank/apt_cache/brit2_view0_cv.mat';
      gtfile_traintime = '';
      vwi = 1;
      lblfile = '/groups/branson/bransonlab/apt/experiments/data/wheel_rig_tracker_DEEP_cam2.lbl';
      pttypes = {'Back foot',[1,2]
        'Tail',3};
    end
    condinfofile = '';
    gtdata_size = load(gtfile_trainsize);
    nlabels = size(gtdata_size.(nets{end}){end}.labels,1);
    npts = size(gtdata_size.(nets{end}){end}.labels,2);
    
    conddata = [];
    % conditions:
    % enriched + activation
    % not enriched + activation
    % not activation
    % data types:
    % train
    % not train
    labeltypes = {};
    datatypes = {};
    %     pttypes = {'L. antenna tip',1
    %       'R. antenna tip',2
    %       'L. antenna base',3
    %       'R. antenna base',4
    %       'Proboscis roof',5};
    %     labeltypes = {'all',1};
    %     datatypes = {'all',1};
    maxerr = 100;
    gtimagefile = '/groups/branson/home/bransonk/tracking/code/APT/BSTrainCVInfo20190416.mat';    
    
    freezeInfo = struct;
    freezeInfo.i = 1;
    doplotoverx = false;
    gtimdatain = load(gtimagefile);
    realvwi = str2double(regexp(exptype,'View(\d+)x','once','tokens'))+1;
    gtimdata = struct;
    gtimdata.cvi = gtimdatain.cvidx{realvwi};
    gtimdata.ppdata = gtimdatain.ppdatas{realvwi};
    gtimdata.tblPGT = gtimdatain.tblPGTs{realvwi};
    gtimdata.frame = gtimdata.tblPGT.frm;
    gtimdata.movieidx = gtimdata.tblPGT.mov;
    gtimdata.movies = gtimdatain.trnmovies{realvwi};
    gtimdata.target = gtimdata.tblPGT.iTgt;
    
    
%     pttypes = {'abdomen',19
%       'front leg joint 1',[13,16]
%       'front leg joint 2',[7,10]
%       'front leg tarsi',[1,4]
%       'middle leg joint 1',[14,17]
%       'middle leg joint 2',[8,11]
%       'middle leg tarsi',[2,5]
%       'back leg joint 1',[15,18]
%       'back leg joint 2',[9,12]
%       'back leg tarsi',[3,6]};
    
  case 'FlyBubbleMDNvsDLC',
    gtfile_trainsize = '/groups/branson/home/robiea/Projects_data/Labeler_APT/Austin_labelerprojects_expandedbehaviors/GT/MDNvsDLC_20190530.mat';
    gtfile_trainsize_cpr = '';
    gtfile_traintime = '';
    gtfile_traintime_cpr = '';
    conddata = [];
    gtimagefile = '/groups/branson/home/bransonk/tracking/code/APT/FlyBubbleMDNvsDLC_gtimdata_20190531.mat';
    gtimdata = load(gtimagefile);

    nets = {'DLC','MDN'};
    legendnames = {'DeepLabCut','MDN'};
    nnets = numel(nets);
    colors = [
      0.8500    0.3250    0.0980
      0.4940    0.1840    0.5560
      ];
    labeltypes = {};
    datatypes = {};
    pttypes = {'head',[1,2,3]
      'body',[4,5,6,7]
      'middle leg joint 1',[8,10]
      'middle leg joint 2',[9,11]
      'front leg tarsi',[12,17]
      'middle leg tarsi',[13,16]
      'back leg tarsi',[14,15]};
    lblfile = '/groups/branson/home/bransonk/tracking/code/APT/multitarget_bubble_expandedbehavior_20180425_FxdErrs_OptoParams20181126_mdn20190214_skeledges.lbl';
    maxerr = [];
    doplotoverx = false;
    doAlignCoordSystem = true;
    
    
  otherwise
    error('Unknown exp type %s',exptype);
    
end


% nets = {'openpose','deeplabcut','unet','mdn'};
% nnets = numel(nets);
% colors = [
%   0    0.4470    0.7410
%   0.8500    0.3250    0.0980
%   0.9290    0.6940    0.1250
%   0.4940    0.1840    0.5560
%   ];

%% load in data

gtdata_size = load(gtfile_trainsize);
if isempty(gtfile_traintime),
  gtdata_time = [];
else
  gtdata_time = load(gtfile_traintime);
end
if isempty(annoterrfile),
  annoterrdata = [];
else
  annoterrdata =load(annoterrfile);
end

%% images for overlaying percentile errors 

if ismember(exptype,{'BSView0x','BSView1x','BSView2x'}),
  
  lObj = load(lblfile,'-mat');
  ptcolors = lObj.cfg.LabelPointsPlot.Colors;
  lObj.labeledpos = cellfun(@SparseLabelArray.full,lObj.labeledpos,'uni',0);
  
else
  lObj = StartAPT;
  lObj.projLoad(lblfile);
  ptcolors = lObj.LabelPointColors;
end

% nets = {'openpose','leap','deeplabcut','unet','mdn'};
% nnets = numel(nets);
% minerr = 0;
% maxerr = 50;
% nbins = 100;
% binedges = linspace(minerr,maxerr,nbins+1);
% bincenters = (binedges(1:end-1)+binedges(2:end))/2;
% markers = {'o','s','d','^'};
%binedges(end) = inf;

switch exptype,
  case {'FlyBubble','FlyBubbleMDNvsDLC'},
    freezeInfo = lObj.prevAxesModeInfo;
    lpos = lObj.labeledpos{freezeInfo.iMov}(:,:,freezeInfo.frm,freezeInfo.iTgt);
    if freezeInfo.isrotated,
      lpos = [lpos,ones(size(lpos,1),1)]*freezeInfo.A;
      lpos = lpos(:,1:2);
    end
  case {'SHView0','SHView1','Larva','RFView0','RFView1','Roian'},
    lObj.setMFT(freezeInfo.iMov,freezeInfo.frm,freezeInfo.iTgt);
    vwi = str2double(exptype(end))+1;
    if isnan(vwi),
      vwi = 1;
    end
    freezeInfo.im = get(lObj.gdata.images_all(vwi),'CData');
    freezeInfo.xdata = get(lObj.gdata.images_all(vwi),'XData');
    freezeInfo.ydata = get(lObj.gdata.images_all(vwi),'YData');
    freezeInfo.isrotated = false;
    
    freezeInfo.axes_curr.XDir = get(lObj.gdata.axes_all(vwi),'XDir');
    freezeInfo.axes_curr.YDir = get(lObj.gdata.axes_all(vwi),'YDir');
    if ~isfield(freezeInfo.axes_curr,'XLim'),
      freezeInfo.axes_curr.XLim = get(lObj.gdata.axes_all(vwi),'XLim');
    end
    if ~isfield(freezeInfo.axes_curr,'YLim'),
      freezeInfo.axes_curr.YLim = get(lObj.gdata.axes_all(vwi),'YLim');
    end
    freezeInfo.axes_curr.CameraViewAngleMode = 'auto';
    npts = size(gtdata_size.mdn{1}.labels,2);
    lpos = lObj.labeledpos{freezeInfo.iMov}((vwi-1)*npts+(1:npts),:,freezeInfo.frm,freezeInfo.iTgt);
  case {'BSView0x','BSView1x','BSView2x'},
    freezeInfo.im = gtimdata.ppdata.I{freezeInfo.i};
    freezeInfo.xdata = [1,size(freezeInfo.im,2)];
    freezeInfo.ydata = [1,size(freezeInfo.im,1)];
    freezeInfo.isrotated = false;
    freezeInfo.axes_curr.XDir = 'normal';
    freezeInfo.axes_curr.YDir = 'reverse';
    npts = size(gtdata_size.mdn{1}.labels,2);
    lpos = reshape(gtimdata.ppdata.pGT(freezeInfo.i,:),[npts,2]);
  otherwise
    error('Unknown exptype %s',exptype);
    
end

assert(all(~isnan(lpos(:))));


%% load in cpr data

if ~isempty(gtfile_trainsize_cpr),  
  gtdata_size = AddCPRGTData(gtdata_size,gtfile_trainsize_cpr,lObj.labeledpos,vwi);
end

if ~isempty(gtfile_traintime) && ~isempty(gtfile_traintime_cpr),
  gtdata_time = AddCPRGTData(gtdata_time,gtfile_trainsize_cpr,lObj.labeledpos,vwi);
end

%% compute kappa for OKS computation if there is annotation error data

if ~isempty(annoterrdata),
  kappadistname = 'gamma2';
  switch kappadistname
    case 'gaussian'
      apvals = [50,75];
      meanapvals = 50:5:95;
    case 'gamma2'
      apvals = [30,40,50];
      meanapvals = 30:5:70;
    otherwise
      error('not implemented');
  end
  
  ndatatypes = size(datatypes,1);
  nlabeltypes = size(labeltypes,1);
  npttypes = size(pttypes,1);
  annfns = fieldnames(annoterrdata);
  %kappadistname = 'gamma2';
  [kappa,errs,areas,hfig] = TuneOKSKappa(annoterrdata,'distname',kappadistname,'pttypes',pttypes,'doplot',true,'dormoutliers',true);
  set(hfig,'Units','pixels','Position',[10,10,560,1168]);
  saveas(hfig,fullfile(savedir,sprintf('IntraAnnotatorDistributionFit_%s_%s',kappadistname,exptype)),'svg');
  saveaspdf_JAABA(hfig,fullfile(savedir,sprintf('IntraAnnotatorDistributionFit_%s_%s.pdf',kappadistname,exptype)))
  apk = cell(nnets+numel(annfns),1);
  ap = cell(nnets+numel(annfns),1);
  meanoks = cell(nnets+numel(annfns),1);

  for i = 1:numel(annfns),
    [apk{nnets+i},ap{nnets+i},meanoks{nnets+i}] = ComputeOKSStats(annoterrdata.(annfns{i}){end},kappa,'pttypes',pttypes,...
      'conddata',annoterrdata.(annfns{i}){end},'pttypes',pttypes,'labeltypes',labeltypes,'datatypes',datatypes,...
      'apvals',apvals,'meanapvals',meanapvals,'distname',kappadistname);
  end
  for ndx = 1:nnets,
    [apk{ndx},ap{ndx},meanoks{ndx}] = ComputeOKSStats(gtdata_size.(nets{ndx}){end},kappa,'pttypes',pttypes,...
      'conddata',conddata,'pttypes',pttypes,'labeltypes',labeltypes,'datatypes',datatypes,...
      'apvals',apvals,'meanapvals',meanapvals,'distname',kappadistname);
  end

  fid = fopen(fullfile(savedir,sprintf('apoksdata_%s_%s.tex',kappadistname,exptype)),'w');
  fprintf(fid,'distname = %s\\\\\n',kappadistname);
  fprintf(fid,'AP averaged over OKS = %s\\\\\n\n',mat2str(meanapvals));
  for datai = ndatatypes,
    for labeli = 1:nlabeltypes,      
      fprintf(fid,['\\begin{tabular}{|c||',repmat('c|',[1,nnets+numel(annfns)]),'}']);
      fprintf(fid,'\\hline\n');
      fprintf(fid,'Measure - %s',labeltypes{labeli});
      for i = 1:nnets,
        fprintf(fid,' & %s',legendnames{i});
      end
      for i = 1:numel(annfns),
        fprintf(fid,' & %s',annfns{i});
      end
      fprintf(fid,'\\\\\\hline\\hline\n');
      
      fprintf(fid,'AP');
      for ndx = 1:nnets+numel(annfns),
        fprintf(fid,' & %.2f',ap{ndx}(1,datai,labeli));
      end
      fprintf(fid,'\\\\\\hline\n');
      for pti = 1:npttypes,
        fprintf(fid,'AP/%s',pttypes{pti,1});
        for ndx = 1:nnets+numel(annfns),
          fprintf(fid,' & %.2f',ap{ndx}(1+pti,datai,labeli));
        end
        fprintf(fid,'\\\\\\hline\n');
      end
      for k = 1:numel(apvals),
        fprintf(fid,'AP-OKS=%d',apvals(k));
        for ndx = 1:nnets+numel(annfns),
          fprintf(fid,' & %.2f',apk{ndx}(k,1,datai,labeli));
        end
        fprintf(fid,'\\\\\\hline\n');
      end
      for pti = 1:npttypes,
        for k = 1:numel(apvals),
          fprintf(fid,'AP-OKS=%d/%s',apvals(k),pttypes{pti,1});
          for ndx = 1:nnets+numel(annfns),
            fprintf(fid,' & %.2f',apk{ndx}(k,1+pti,datai,labeli));
          end
          fprintf(fid,'\\\\\\hline\n');
        end
      end
      fprintf(fid,'\\end{tabular}\n\n');
    end
  end
  fclose(fid);

end

%% compute average precision at various thresholds relative to the animal scale

ComputePixelPrecisionTable(gtdata_size,...
  'nets',nets,'legendnames',legendnames,...
  'exptype',exptype,...
  'conddata',conddata,...
  'labeltypes',labeltypes,'datatypes',datatypes,...
  'savedir',savedir,...
  'dosavefig',dosavefig,...
  'pttypes',pttypes,...
  'annoterrdata',annoterrdata);

%% plot error percentiles per part type over training time

if doplotoverx && ~isempty(gtdata_time),

PlotPerLandmarkErrorPrctilesOverX('gtdata',gtdata_time,...
  'nets',nets,'legendnames',legendnames,...
  'colors',colors,...
  'exptype',exptype,...
  'conddata',conddata,...
  'labeltypes',labeltypes,'datatypes',datatypes,...
  'prcs',prcs,...
  'pttypes',pttypes,...
  'savedir',savedir,...
  'maxerr',maxerr,...
  'dosavefig',dosavefig,...
  'x','Training time (h)',...
  'savekey','TrainTime');
end


%% plot error percentiles for worst part over training time

if doplotoverx && ~isempty(gtdata_time),

for stati = 1:3,
  switch stati,
    case 1
      statname = 'Worst';
    case 2
      statname = 'Median';
    case 3
      statname = 'Best';
  end

  hfigs = PlotWorstLandmarkErrorOverX('gtdata',gtdata_time,...
    'statname',statname,...
    'nets',nets,'legendnames',legendnames,...
    'colors',colors,...
    'exptype',exptype,...
    'conddata',conddata,...
    'labeltypes',labeltypes,'datatypes',datatypes,...
    'prcs',prcs,...
    'savedir',savedir,...
    'maxerr',maxerr,...
    'dosavefig',dosavefig,...
    'x','Training time (h)',...
    'savekey','TrainTime');
  
end

end

%% plot error percentiles per part type over training set size

if doplotoverx,
  PlotPerLandmarkErrorPrctilesOverX('gtdata',gtdata_size,...
    'nets',nets,'legendnames',legendnames,...
    'colors',colors,...
    'exptype',exptype,...
    'conddata',conddata,...
    'labeltypes',labeltypes,'datatypes',datatypes,...
    'prcs',prcs,...
    'pttypes',pttypes,...
    'savedir',savedir,...
    'maxerr',maxerr,...
    'dosavefig',dosavefig,...
    'x','N. training examples',...
    'savekey','TrainSetSize');
  
end

%% plot error percentiles for worst part over training set size

if doplotoverx,
  
  for stati = 1:3,
    switch stati,
      case 1
        statname = 'Worst';
      case 2
        statname = 'Median';
      case 3
        statname = 'Best';
    end
    
    hfigs = PlotWorstLandmarkErrorOverX('gtdata',gtdata_size,...
      'statname',statname,...
      'nets',nets,'legendnames',legendnames,...
      'colors',colors,...
      'exptype',exptype,...
      'conddata',conddata,...
      'labeltypes',labeltypes,'datatypes',datatypes,...
      'prcs',prcs,...
      'savedir',savedir,...
      'maxerr',maxerr,...
      'dosavefig',dosavefig,...
      'x','N. training examples',...
      'savekey','TrainSetSize');
    
    
%     if ~isempty(annoterrdata),
%       worsterr = max(sqrt(sum((annoterrdata.inter{end}.pred-annoterrdata.inter{end}.labels).^2,3)),[],2);
%       medianterworsterr = median(worsterr);
%     end
  
  end
  
end

%% overlay error percentiles per part for last entry

PlotOverlayedErrorPrctiles('freezeInfo',freezeInfo,...
  'lpos',lpos,...
  'gtdata',gtdata_size,...
  'nets',nets,'legendnames',legendnames,...
  'exptype',exptype,...
  'conddata',conddata,...
  'labeltypes',labeltypes,'datatypes',datatypes,...
  'prcs',prcs,...
  'savedir',savedir,...
  'dosavefig',dosavefig);

%% plot error percentiles per part type for last entry

PlotPerLandmarkErrorPrctiles('gtdata',gtdata_size,...
  'nets',nets,'legendnames',legendnames,...
  'colors',colors,...
  'exptype',exptype,...
  'conddata',conddata,...
  'labeltypes',labeltypes,'datatypes',datatypes,...
  'prcs',prcs,...
  'pttypes',pttypes,...
  'savedir',savedir,...
  'maxerr',maxerr,...
  'dosavefig',dosavefig);
  
%% plot error vs number of inliers, prctile vs error for worst, median, and best landmark

clear hfigs;

if ~isempty(annoterrdata),
  cur_annoterrdata = annoterrdata.inter{end};
else
  cur_annoterrdata = [];
end

for stati = 1:3,
  switch stati,
    case 1
      statname = 'Worst';
    case 2
      statname = 'Median';
    case 3
      statname = 'Best';
  end
  
  
  PlotFracInliers('gtdata',gtdata_size,...
    'nets',nets,'legendnames',legendnames,...
    'colors',colors,...
    'exptype',exptype,...
    'conddata',conddata,...
    'labeltypes',labeltypes,'datatypes',datatypes,...
    'statname',statname,...
    'savedir',savedir,'dosavefig',dosavefig,...
    'maxerr',maxerr,...
    'prcs',prcs,...
    'maxprc',99.5,...
    'annoterrdata',cur_annoterrdata,...
    'annoterrprc',99);
  
  
  PlotSortedWorstLandmarkError('gtdata',gtdata_size,...
    'nets',nets,'legendnames',legendnames,...
    'colors',colors,...
    'exptype',exptype,...
    'conddata',conddata,...
    'labeltypes',labeltypes,'datatypes',datatypes,...
    'statname',statname,...
    'savedir',savedir,'dosavefig',dosavefig,'maxerr',maxerr,...
    'prcs',prcs,...
    'maxprc',99.5,...
    'annoterrdata',cur_annoterrdata,...
    'annoterrprc',99);

  
end

%% plot example predictions

nexamples_random = 5;
nexamples_disagree = 5;
errnets = {'mdn','deeplabcut'};
hfigs = PlotExamplePredictions('gtdata',gtdata_size,...
  'gtimdata',gtimdata,...
  'lObj',lObj,...
  'nets',nets,'legendnames',legendnames,...
  'exptype',exptype,...
  'ptcolors',ptcolors,...
  'conddata',conddata,'labeltypes',labeltypes,'datatypes',datatypes,...
  'dosavefig',dosavefig,'savedir',savedir,...
  'nexamples_random',nexamples_random,...
  'nexamples_disagree',nexamples_disagree,...
  'doAlignCoordSystem',doAlignCoordSystem,...
  'errnets',errnets);

%% plot errors against each other for MDNvsDLC

if ismember(exptype,{'FlyBubbleMDNvsDLC'}),
  err = nan(size(gtdata_size.(nets{1}){end}.labels,1),nnets);
  for ndx = 1:nnets,
    err(:,ndx) = max(sqrt(sum((gtdata_size.(nets{ndx}){end}.labels-gtdata_size.(nets{ndx}){end}.pred).^2,3)),[],2);
  end
  hfig = figure;
  clf;
  maxerrcurr = max(err(:))*1.05;
  hold on;
  plot([0,maxerrcurr],[0,maxerrcurr],'c-');
  plot(err(:,1),err(:,2),'k.','MarkerFaceColor','k');
  axis equal;
  set(gca,'XLim',[0,maxerrcurr],'YLim',[0,maxerrcurr]);
  xlabel(sprintf('%s worst landmark error',legendnames{1}));
  ylabel(sprintf('%s worst landmark error',legendnames{2}));
  set(hfig,'Renderer','painters','Units','pixels','Position',[10,10,300,300]);
  saveas(hfig,fullfile(savedir,sprintf('%s_DLCErrorVsMDNError.svg',exptype)),'svg')
end

%% print data set info

strippedLblFile = struct;
strippedLblFile.SH = '/groups/branson/bransonlab/apt/experiments/data/sh_trn4992_gtcomplete_cacheddata_updated20190402_dlstripped.lbl';
strippedLblFile.FlyBubble = '/groups/branson/bransonlab/apt/experiments/data/multitarget_bubble_expandedbehavior_20180425_FxdErrs_OptoParams20181126_dlstripped.lbl';
strippedLblFile.RF = '/groups/branson/bransonlab/apt/experiments/data/romain_dlstripped.lbl';
strippedLblFile.BSView0x = '/groups/branson/bransonlab/apt/experiments/data/britton_dlstripped_0.lbl';
strippedLblFile.BSView1x = '/groups/branson/bransonlab/apt/experiments/data/britton_dlstripped_1.lbl';
strippedLblFile.BSView2x = '/groups/branson/bransonlab/apt/experiments/data/britton_dlstripped_2.lbl';
strippedLblFile.Roian = '/groups/branson/bransonlab/apt/experiments/data/roian_apt_dlstripped.lbl';
strippedLblFile.Larva = '/groups/branson/bransonlab/apt/experiments/data/larva_dlstripped_20190420.lbl';

gtResFile = struct;
gtResFile.SH = '/nrs/branson/mayank/apt_cache/stephen_view0_trainsize.mat';
gtResFile.FlyBubble = '/nrs/branson/mayank/apt_cache/alice_view0_trainsize.mat';

fns = fieldnames(strippedLblFile);
nTrain = struct;
nGT = struct;
for i = 1:numel(fns),
  fn = fns{i};
  ld = load(strippedLblFile.(fn),'-mat');
  nTrain.(fn) = size(ld.preProcData_I,1);
  fprintf('%s\t%d',fn,nTrain.(fn));
  if isfield(gtResFile,fn),
    gd = load(gtResFile.(fn));
    nGT.(fn) = size(gd.mdn{end}.pred,1);
    fprintf('\t%d',nGT.(fn));
  end
  fprintf('\n');
  
end
    

%% old stuff


% %% plot example predictions
% 
% rng(0);
% nexamples_random = 5;
% nexamples_disagree = 5;
% ms = 8;
% lw = 2;
% ndatapts = numel(conddata.data_cond);
% netsplot = find(isfield(gtdata_size,nets));
% landmarkColors = lObj.labelPointsPlotInfo.Colors;
% ndatatypes = size(datatypes);
% nlabeltypes = size(labeltypes);
% figpos = [10,10,1332,1468];
% 
% for datai = 1:ndatatypes,
%   for labeli = 1:nlabeltypes,
%     isselected = false(ndatapts,1);
%     idx = find(ismember(conddata.data_cond,datatypes{datai,2})&ismember(conddata.label_cond,labeltypes{labeli,2})&~isselected);
%     if isempty(idx),
%       continue;
%     end
%     hfigs(datai,labeli) = figure;
%     set(hfigs(datai,labeli),'Units','pixels','Position',figpos,'Renderer','painters');
%     
%     allpreds = nan([size(gtdata_size.(nets{netsplot(1)}){end}.pred),numel(netsplot)]);
%     
%     for netii = 1:numel(netsplot),
%       neti = netsplot(netii);
%       
%       predscurr = gtdata_size.(nets{neti}){end}.pred;
%       if ~isempty(strfind(nets{neti},'cpr')),
%         
%         tblP = gtimdata.tblPGT;
%         [ndatapts,nlandmarks,d] = size(predscurr);
%         % doing this manually, can't find a good function to do it
%         preds = gtdata_size.(nets{neti}){end}.pred;
%         for i = 1:ndatapts,
%           pAbs = permute(preds(i,:,:),[2,3,1]);
%           x = tblP.pTrx(i,1);
%           y = tblP.pTrx(i,2);
%           theta = tblP.thetaTrx(i);
%           T = [1,0,0
%             0,1,0
%             -x,-y,1];
%           R = [cos(theta+pi/2),-sin(theta+pi/2),0
%             sin(theta+pi/2),cos(theta+pi/2),0
%             0,0,1];
%           A = T*R;
%           tform = maketform('affine',A);
%           [pRel(:,1),pRel(:,2)] = ...
%             tformfwd(tform,pAbs(:,1),pAbs(:,2));
%           pRoi = lObj.preProcParams.TargetCrop.Radius+pRel;
%           predscurr(i,:,:) = pRoi;
%         end
%       end
%       allpreds(:,:,:,netii) = predscurr;
%     end
%     
%     if nexamples > numel(idx),
%       exampleidx = idx;
%       exampleinfo = repmat({'Rand'},[numel(exampleidx),1]);
% 
%     else
%       medpred = median(allpreds(idx,:,:,:),4);
%       disagreement = max(max(sqrt(sum( (allpreds(idx,:,:,:)-medpred).^2,3 )),[],4),[],2);
%       [sorteddisagreement,order] = sort(disagreement,1,'descend');
%       exampleidx_disagree = idx(order(1:nexamples_disagree));
%       isselected(exampleidx_disagree) = true;
%       idx = find(ismember(conddata.data_cond,datatypes{datai,2})&ismember(conddata.label_cond,labeltypes{labeli,2})&~isselected);
%       exampleidx_random = randsample(idx,nexamples_random);
%       isselected(exampleidx_random) = true;
%       exampleidx = [exampleidx_random;exampleidx_disagree];
%       exampleinfo = repmat({'Rand'},[numel(exampleidx_random),1]);
%       for i = 1:nexamples_disagree,
%         exampleinfo{end+1} = sprintf('%.1f',sorteddisagreement(i)); %#ok<SAGROW>
%       end
%       
%     end
%     hax = createsubplots(nexamples,numel(netsplot)+2,0);%[[.025,0],[.025,0]]);
%     hax = reshape(hax,[nexamples,numel(netsplot)+2]);
%     hax = hax';
%     labelscurr = gtdata_size.(nets{netsplot(1)}){end}.labels;
%     for exii = 1:numel(exampleidx),
%       exi = exampleidx(exii);
%       imagesc(gtimdata.ppdata.I{exi},'Parent',hax(1,exii));
%       axis(hax(1,exii),'image','off');
%       hold(hax(1,exii),'on');
%       for pti = 1:npts,
%         plot(hax(1,exii),labelscurr(exi,pti,1),labelscurr(exi,pti,2),'+','Color',landmarkColors(pti,:),'MarkerSize',ms,'LineWidth',lw);
%       end
%       text(1,size(gtimdata.ppdata.I{exi},1)/2,...
%         sprintf('%d, %s (Mov %d, Tgt %d, Frm %d)',exi,exampleinfo{exii},...
%         -gtimdata.tblPGT.mov(exi),gtimdata.tblPGT.iTgt(exi),gtimdata.tblPGT.frm(exi)),...
%         'Rotation',90,'HorizontalAlignment','center','VerticalAlignment','top','Parent',hax(1,exii),'FontSize',6);
%     end
%     exi = exampleidx(1);
%     text(size(gtimdata.ppdata.I{exi},2)/2,1,'Groundtruth','HorizontalAlignment','center','VerticalAlignment','top','Parent',hax(1,1));
%     
%     for exii = 1:numel(exampleidx),
%       exi = exampleidx(exii);
%       imagesc(gtimdata.ppdata.I{exi},'Parent',hax(2,exii));
%       axis(hax(2,exii),'image','off');
%       hold(hax(2,exii),'on');
%       for pti = 1:npts,
%         plot(hax(2,exii),labelscurr(exi,pti,1),labelscurr(exi,pti,2),'+','Color',landmarkColors(pti,:),'MarkerSize',ms,'LineWidth',lw);
%       end
%       for pti = 1:npts,
%         plot(hax(2,exii),squeeze(allpreds(exi,pti,1,:)),squeeze(allpreds(exi,pti,2,:)),'.','Color',ptcolors(pti,:),'MarkerSize',ms,'LineWidth',lw);
%       end
%     end
%     exi = exampleidx(1);
%     text(size(gtimdata.ppdata.I{exi},2)/2,1,'All','HorizontalAlignment','center','VerticalAlignment','top','Parent',hax(2,1));
% 
%     
%     for netii = 1:numel(netsplot),
%       neti = netsplot(netii);
%       
%       predscurr = allpreds(:,:,:,netii);
%       
%       for exii = 1:numel(exampleidx),
%         exi = exampleidx(exii);
%         imagesc(gtimdata.ppdata.I{exi},'Parent',hax(netii+2,exii));
%         axis(hax(netii+2,exii),'image','off');
%         hold(hax(netii+2,exii),'on');
%         for pti = 1:npts,
%           plot(hax(netii+2,exii),predscurr(exi,pti,1),predscurr(exi,pti,2),'+','Color',landmarkColors(pti,:),'MarkerSize',ms,'LineWidth',lw);
%         end
%         err = max(sqrt(sum((predscurr(exi,:,:)-labelscurr(exi,:,:)).^2,3)));
%         text(size(gtimdata.ppdata.I{exi},2)/2,size(gtimdata.ppdata.I{exi},1),num2str(err),'HorizontalAlignment','center','VerticalAlignment','bottom','Parent',hax(netii+2,exii));
%       end
%       text(size(gtimdata.ppdata.I{exi},2)/2,1,legendnames{neti},'HorizontalAlignment','center','VerticalAlignment','top','Parent',hax(netii+2,1));
%     end
%     colormap(hfigs(datai,labeli),'gray');
% 
%     set(hfigs(datai,labeli),'Name',sprintf('Examples: %s, %s, %s',exptype,datatypes{datai,1},labeltypes{labeli,1}));
%     savenames{datai,labeli} = fullfile(savedir,sprintf('%s_Examples_%s_%s.svg',exptype,datatypes{datai,1},labeltypes{labeli,1}));
%     saveas(hfigs(datai,labeli),savenames{datai,labeli},'svg');
%           
%   end
% end

% nbins = 60;
% binedges = linspace(minerr,maxerr,nbins+1);
% bincenters = (binedges(1:end-1)+binedges(2:end))/2;
% prcs = [50,75,90,95,97];%,99];
% markers = {'o','s','<','^','v','>'};
% nprcs = numel(prcs);
% 
% npttypes = size(pttypes,1);
% nlabeltypes = size(labeltypes,1);
% ndatatypes = size(datatypes,1);

% %% compute stats for error as a function of training set size
% 
% gtdata_size = load(gtfile_trainsize);
% if ~isempty(gtfile_trainsize_cpr),
%   gtdata_cpr = load(gtfile_trainsize_cpr);
% end
% newfns = setdiff(fieldnames(gtdata_cpr),fieldnames(gtdata_size));
% for i = 1:numel(newfns),
%   gtdata_size.(newfns{i}) = gtdata_cpr.(newfns{i});
% end
% 
% 
% %nets = fieldnames(gtdata);
% npts = size(gtdata_size.mdn{1}.labels,2);
% 
% n_models = numel(gtdata_size.(nets{1}));
% n_train = cellfun(@(x) x.model_timestamp,gtdata_size.mdn(2:end));
% 
% errfrac = nan([nbins,nnets,n_models-1,npttypes,nlabeltypes,ndatatypes]);
% errprctiles = nan([nprcs,nnets,n_models-1,npttypes,nlabeltypes,ndatatypes]);
% ndatapts = nan([nnets,n_models-1,npttypes,nlabeltypes,ndatatypes]);
% maxdist = nan([nprcs,nnets,n_models-1,nlabeltypes,ndatatypes]);
% mindist = nan([nprcs,nnets,n_models-1,nlabeltypes,ndatatypes]);
% mediandist = nan([nprcs,nnets,n_models-1,nlabeltypes,ndatatypes]);
% 
% for ndx = 1:nnets,
%   for mndx = 2:n_models
%     if numel(gtdata_size.(nets{ndx})) < mndx,
%       break;
%     end
%     cur_data = gtdata_size.(nets{ndx}){mndx};
%     preds = cur_data.pred;
%     labels = cur_data.labels;
%     assert(size(preds,3)==2);
%     assert(size(labels,3)==2);
%     iscpr = ~isempty(strfind(nets{ndx},'cpr'));
%     
%     for datai = 1:ndatatypes,
%       dtis = datatypes{datai,2};
%       for labeli = 1:nlabeltypes,
%         ltis = labeltypes{labeli,2};
%         idx = ismember(conddata.data_cond,dtis) & ismember(conddata.label_cond,ltis);
%         if iscpr && isshexp,
%           % special case for SH/cpr whose computed GT output only has
%           % 1149 rows instead of 1150 cause dumb
%           idx(4) = [];
%         end
%         
%         for typei = 1:npttypes,
%           ptis = pttypes{typei,2};
%           if all(idx)
%             dist = sqrt(sum( (preds(:,ptis,:)-labels(:,ptis,:)).^2,3)); 
%           else
%             dist = sqrt(sum( (preds(idx,ptis,:)-labels(idx,ptis,:)).^2,3));
%           end
%           counts = hist(dist(:),bincenters);
%           ndatapts(ndx,mndx-1,typei,labeli,datai) = sum(counts);
%           errfrac(:,ndx,mndx-1,typei,labeli,datai) = counts;
%           errprctiles(:,ndx,mndx-1,typei,labeli,datai) = prctile(dist(:),prcs);
%         end
%         dist = sqrt(sum( (preds(idx,:,:)-labels(idx,:,:)).^2,3));
%         maxdistcurr = max(dist,[],2);
%         mediandistcurr = median(dist,2);
%         mindistcurr = min(dist,[],2);
%         maxdist(:,ndx,mndx-1,labeli,datai) = prctile(maxdistcurr(:),prcs);
%         mediandist(:,ndx,mndx-1,labeli,datai) = prctile(mediandistcurr(:),prcs);
%         mindist(:,ndx,mndx-1,labeli,datai) = prctile(mindistcurr(:),prcs);
%         
%       end
%     end
% 
%   end
% end

% %% plot stats as a function of training set size - hist
% 
% 
% offs = linspace(-.3,.3,nnets);
% doff = offs(2)-offs(1);
% dx = [-1,1,1,-1,-1]*doff/2;
% dy = [0,0,1,1,0];
% 
% hfigs = gobjects(1,ndatatypes);
% 
% for datai = ndatatypes:-1:1,
% 
%   hfigs(datai) = figure;
%   clf;
%   set(hfigs(datai),'Position',[10,10,2526,150+1004/4*nlabeltypes]);
%   hax = createsubplots(nlabeltypes,npttypes,[[.025,.005];[.05,.005]]);
%   hax = reshape(hax,[nlabeltypes,npttypes]);
%   
%   for labeli = 1:nlabeltypes,
%   
%     for pti = 1:npttypes,
%   
%       axes(hax(labeli,pti));
%   
%       hold on;
% 
%       maxfrac = max(max(max(errfrac(:,:,:,pti,labeli,datai))));
%       
%       h = gobjects(1,nnets);
%       hprcs = gobjects(1,nprcs);
%       for ndx = 1:nnets,
%         for mndx = 2:n_models
%           offx = mndx-1 + offs(ndx);
%           if numel(gtdata.(nets{ndx})) < mndx,
%             patch(offx+dx,minerr+maxerr*dy,[.7,.7,.7],'LineStyle','none');
%             break;
%           end
%       
%           for bini = 1:nbins,
%             colorfrac = min(1,errfrac(bini,ndx,mndx-1,pti,labeli,datai)/maxfrac);
%             if colorfrac == 0,
%               continue;
%             end
%             patch(offx+dx,binedges(bini+dy),colors(ndx,:)*colorfrac + 1-colorfrac,'LineStyle','none');
%           end
%           for prci = 1:nprcs,
%             hprcs(prci) = plot(offx,min(maxerrplus,errprctiles(prci,ndx,mndx-1,pti,labeli,datai)),'w','MarkerFaceColor',colors(ndx,:),'Marker',markers{prci});
%           end
%         end
%         h(ndx) = patch(nan(size(dx)),nan(size(dx)),colors(ndx,:),'LineStyle','none');
%       end
%   
%       set(gca,'XTick',1:n_models-1,'XTickLabels',num2str(n_train(:)));
%   
%       if pti == 1 && labeli == 1,
%         legend([h,hprcs],[legendnames,arrayfun(@(x) sprintf('%d %%ile',x),prcs,'Uni',0)]);
%       end
%       if labeli == nlabeltypes,
%         xlabel('N. training examples');
%       end
%       if pti == 1,
%         ylabel(labeltypes{labeli,1});
%       end
%       if labeli == 1,
%         title(pttypes{pti,1},'FontWeight','normal');
%       end
%       set(gca,'XLim',[0,n_models],'YLim',[0,maxerrplus]);
%       drawnow;
%     end
%     set(hax(:,2:end),'YTickLabel',{});
%     set(hax(1:end-1,:),'XTickLabel',{});
%     
%   end
%   set(hfigs(datai),'Name',datatypes{datai,1});
%   set(hfigs(datai),'Renderer','painters');
%   break
%   %savefig(hfigs(datai),sprintf('FlyBubble_GTTrackingError_TrainingSetSize_%s.fig',datatypes{datai,1}),'compact');
%   saveas(hfigs(datai),sprintf('%s_GTTrackingError_TrainingSetSize_%s.svg',exptype,datatypes{datai,1}),'svg');
% 
% end

% %% plot stats as a function of training set size - prctiles
% 
% 
% offs = linspace(-.3,.3,nnets);
% doff = offs(2)-offs(1);
% dx = [-1,1,1,-1,-1]*doff/2;
% dy = [0,0,1,1,0];
% 
% hfigs = gobjects(1,ndatatypes);
% 
% for datai = ndatatypes:-1:1,
% 
%   hfigs(datai) = figure;
%   clf;
%   set(hfigs(datai),'Position',[10,10,2526/2,(150+1004/4*nlabeltypes)/2]);
%   hax = createsubplots(nlabeltypes,npttypes,[[.025,.005];[.1,.005]]);
%   hax = reshape(hax,[nlabeltypes,npttypes]);
% 
%   for nprcsplot = 1:nprcs,
%   
%   for labeli = 1:nlabeltypes,
%   
%     for pti = 1:npttypes,
%   
%       axes(hax(labeli,pti));
%       cla(hax(labeli,pti));
%   
%       hold on;
% 
%       maxfrac = max(max(max(errfrac(:,:,:,pti,labeli,datai))));
%       
%       h = gobjects(1,nnets);
%       hprcs = gobjects(1,nprcs);
%       for ndx = 1:nnets,
%         for mndx = 2:n_models
%           offx = mndx-1 + offs(ndx);
%           if numel(gtdata_size.(nets{ndx})) < mndx,
%             patch(offx+dx,minerr+maxerr*dy,[.7,.7,.7],'LineStyle','none');
%             break;
%           end
%           
%           
%           for prci = nprcsplot:-1:1,
%             colorfrac = colorfracprcs(prci);
%             tmp = [0,errprctiles(prci,ndx,mndx-1,pti,labeli,datai)];
%             patch(offx+dx,tmp(1+dy),colors(ndx,:)*colorfrac + 1-colorfrac,'EdgeColor',colors(ndx,:));
%           end
%       
%         end
%         if pti == 1 && labeli == 1,
%           h(ndx) = patch(nan(size(dx)),nan(size(dx)),colors(ndx,:),'LineStyle','none');
%         end
%       end
%   
%       set(gca,'XTick',1:n_models-1,'XTickLabels',num2str(n_train(:)));
%   
%       if pti == 1 && labeli == 1 && nprcsplot == nprcs,
%         hprcs = gobjects(1,nprcs);
%         for prci = 1:nprcs,
%           hprcs(prci) = patch(nan(size(dx)),nan(size(dx)),[1,1,1]-colorfracprcs(prci),'EdgeColor','k');
%         end
%         legend([h,hprcs],[legendnames,arrayfun(@(x) sprintf('%d %%ile',x),prcs,'Uni',0)]);
%       end
%       if labeli == nlabeltypes,
%         xlabel('N. training examples');
%       end
%       if pti == 1,
%         ylabel(labeltypes{labeli,1});
%       end
%       if labeli == 1,
%         title(pttypes{pti,1},'FontWeight','normal');
%       end
%       set(gca,'XLim',[0,n_models],'YLim',[0,maxerrplus]);
%       drawnow;
%     end
%     set(hax(:,2:end),'YTickLabel',{});
%     set(hax(1:end-1,:),'XTickLabel',{});
%     
%   end
%   set(hfigs(datai),'Name',datatypes{datai,1});
%   set(hfigs(datai),'Renderer','painters');
%   %keyboard;
%   %savefig(hfigs(datai),sprintf('FlyBubble_GTTrackingError_TrainingSetSize_%s.fig',datatypes{datai,1}),'compact');
%   saveas(hfigs(datai),fullfile(savedir,sprintf('%s_GTTrackingError_TrainingSetSize_Prctile%d_%s.svg',exptype,nprcsplot,datatypes{datai,1})),'svg');
%   end
%   %break;
% end

% %% plot worst error percentiles
% 
% clear hfigs;
% 
% for stati = 1:3,
%   switch stati,
%     case 1
%       statname = 'Worst';
%       statdist = maxdist;
%     case 2
%       statname = 'Median';
%       statdist = mediandist;
%     case 3
%       statname = 'Best';
%       statdist = mindist;
%   end
%   
%   
%   for datai = ndatatypes:-1:1,
%     
%     hfigs(datai,stati) = figure;
%     clf;
%     set(hfigs(datai,stati),'Position',[10,10,2526/2,(150+1004/4*nlabeltypes)/2]);
%     hax = createsubplots(nlabeltypes,nprcs,[[.025,.005];[.1,.005]]);
%     hax = reshape(hax,[nlabeltypes,nprcs]);
%     
%     for prci= 1:nprcs,
%       
%       minv = min(min(min(min(statdist(prci,:,:,:,:)))));
%       
%       for labeli = 1:nlabeltypes,
%         
%         axes(hax(labeli,prci));
%         cla(hax(labeli,prci));
%         
%         hold on;
%         h = gobjects(1,nnets);
%         for ndx = 1:nnets,
%           h(ndx) = plot(1:n_models-1,squeeze(statdist(prci,ndx,:,labeli,datai))','.-','LineWidth',2,'Color',colors(ndx,:),'MarkerSize',12);
%         end
%         set(gca,'XTick',1:n_models-1,'XTickLabels',num2str(n_train(:)));
%         if labeli == 1 && prci == 1,
%           legend(h,legendnames);
%         end
%         if labeli == nlabeltypes,
%           xlabel('N. training examples');
%         end
%         if prci == 1,
%           ylabel(labeltypes{labeli,1});
%         end
%         if labeli == 1,
%           title(sprintf('%dth %%ile, %s landmark',prcs(prci),statname),'FontWeight','normal');
%         end
%         set(gca,'XLim',[0,n_models],'YLim',[minv,maxerrplus]);
%         drawnow;
%         set(hax(labeli,prci),'YScale','log');
%       end
%       linkaxes(hax(:,prci));
%     end
%     set(hax(:,2:end),'YTickLabel',{});
%     set(hax(1:end-1,:),'XTickLabel',{});
%     
%     set(hfigs(datai,stati),'Name',sprintf('%s landmark, %s',lower(statname),datatypes{datai,1}));
%     set(hfigs(datai,stati),'Renderer','painters');
%     %keyboard;
%     %savefig(hfigs(datai),sprintf('FlyBubble_GTTrackingError_TrainingSetSize_%s.fig',datatypes{datai,1}),'compact');
%     saveas(hfigs(datai),fullfile(savedir,sprintf('%s_GTTrackingError_TrainingSetSize_%sLandmark_%s.svg',exptype,statname,datatypes{datai,1})),'svg');
%   end
% end

% %%
% gtdata_size = load(gtfile_traintime);
% 
% %nets = fieldnames(gtdata);
% npts = size(gtdata_size.mdn{1}.labels,2);
% 
% n_models = 0;
% for ndx = 1:nnets,
%   if ~isfield(gtdata_size,nets{ndx}),
%     continue;
%   end
%   n_models = max(n_models,numel(gtdata_size.(nets{ndx})));
% end
% train_time = nan(nnets,n_models-1);
% for ndx = 1:nnets,
% 
%   if ~isfield(gtdata_size,nets{ndx}),
%     continue;
%   end
%   ts = cellfun(@(x) x.model_timestamp,gtdata_size.(nets{ndx}));
%   train_time(ndx,1:numel(ts)-1) = (ts(2:end)-ts(1))/3600;
% end
% 
% errfrac = nan([nbins,nnets,n_models-1,npttypes,nlabeltypes,ndatatypes]);
% errprctiles = nan([nprcs,nnets,n_models-1,npttypes,nlabeltypes,ndatatypes]);
% ndatapts = nan([nnets,n_models-1,npttypes,nlabeltypes,ndatatypes]);
% 
% for ndx = 1:nnets,
%   if ~isfield(gtdata_size,nets{ndx}),
%     continue;
%   end
% 
%   for mndx = 2:n_models
%     
%     if numel(gtdata_size.(nets{ndx})) < mndx,
%       break;
%     end
%     if ~isfield(gtdata_size,nets{ndx}),
%       continue;
%     end
%     cur_data = gtdata_size.(nets{ndx}){mndx};
%     preds = cur_data.pred;
%     labels = cur_data.labels;
%     assert(size(preds,3)==2);
%     assert(size(labels,3)==2);
%    
%     for datai = 1:ndatatypes,
%       dtis = datatypes{datai,2};
%       for labeli = 1:nlabeltypes,
%         ltis = labeltypes{labeli,2};
%         idx = ismember(conddata.data_cond,dtis) & ismember(conddata.label_cond,ltis);
%         for typei = 1:npttypes,
%           ptis = pttypes{typei,2};
%           dist = sqrt(sum( (preds(idx,ptis,:)-labels(idx,ptis,:)).^2,3));
%           counts = hist(dist(:),bincenters);
%           ndatapts(ndx,mndx-1,typei,labeli,datai) = sum(counts);
%           errfrac(:,ndx,mndx-1,typei,labeli,datai) = counts ;
%           errprctiles(:,ndx,mndx-1,typei,labeli,datai) = prctile(dist(:),prcs);
%         end
%       end
%     end
% 
%   end
% end
% 
% %% plot stats as a function of training time
% 
% 
% max_train_time = max(train_time(:));
% %patchr = min(pdist(train_time(:)));
% patchr = max_train_time /100;
% dx = [-1,1,1,-1,-1]*patchr;
% dy = [0,0,1,1,0];
% 
% hfigs = gobjects(1,ndatatypes);
% 
% for datai = ndatatypes:-1:1,
% 
%   hfigs(datai) = figure;
%   clf;
%   
%   set(hfigs(datai),'Position',[10,10,2526,150+1004/4*nlabeltypes]);
%   %set(hfigs(datai),'Position',[10,10,2526,1154]);
%   hax = createsubplots(nlabeltypes,npttypes,[[.025,.005];[.05,.005]]);
%   hax = reshape(hax,[nlabeltypes,npttypes]);
%   
%   for labeli = 1:nlabeltypes,
%   
%     for pti = 1:npttypes,
%   
%       axes(hax(labeli,pti));
%   
%       hold on;
% 
%       maxfrac = max(max(max(errfrac(:,:,:,pti,labeli,datai))));
%       
%       h = gobjects(1,nnets);
%       hprcs = gobjects(1,nprcs);
%       for ndx = 1:nnets,
%         for mndx = 2:n_models
%           offx = train_time(ndx,mndx-1);
%           if numel(gtdata_size.(nets{ndx})) < mndx,
%             break;
%           end
%       
%           for bini = 1:nbins,
%             colorfrac = min(1,errfrac(bini,ndx,mndx-1,pti,labeli,datai)/maxfrac);
%             if colorfrac == 0,
%               continue;
%             end
%             patch(offx+dx,binedges(bini+dy),colors(ndx,:)*colorfrac + 1-colorfrac,'LineStyle','none');
%           end
% 
%         end
%         if labeli == 1 && pti == 1,
%           h(ndx) = patch(nan(size(dx)),nan(size(dx)),colors(ndx,:),'LineStyle','none');
%         end
%       end
%       for ndx = 1:nnets,
%         for mndx = 2:n_models
%           offx = train_time(ndx,mndx-1);
%           if numel(gtdata_size.(nets{ndx})) < mndx,
%             break;
%           end
%           for prci = 1:nprcs,
%             hprcs(prci) = plot(offx,min(maxerrplus,errprctiles(prci,ndx,mndx-1,pti,labeli,datai)),'w','MarkerFaceColor',colors(ndx,:),'Marker',markers{prci});
%           end
%         end
%       end
%   
%       %set(gca,'XTick',1:n_models-1,'XTickLabels',num2str(n_train(:)));
%   
%       if pti == 1 && labeli == 1,
%         legend([h,hprcs],[nets,arrayfun(@(x) sprintf('%d %%ile',x),prcs,'Uni',0)]);
%       end
%       if labeli == nlabeltypes,
%         xlabel('Training time (h)');
%       end
%       if pti == 1,
%         ylabel(labeltypes{labeli,1});
%       end
%       if labeli == 1,
%         title(pttypes{pti,1},'FontWeight','normal');
%       end
%       set(gca,'XLim',[min(train_time(:))-3*patchr,max(train_time(:))+3*patchr],'YLim',[0,maxerrplus]);
%       drawnow;
%     end
%     set(hax(:,2:end),'YTickLabel',{});
%     set(hax(1:end-1,:),'XTickLabel',{});
%     
%   end
%   set(hfigs(datai),'Name',datatypes{datai,1});
%   
%   set(hfigs(datai),'Renderer','painters');
%   %savefig(hfigs(datai),sprintf('FlyBubble_GTTrackingError_TrainingTime_%s.fig',datatypes{datai,1}),'compact');
%   saveas(hfigs(datai),sprintf('%s_GTTrackingError_TrainingTime_%s.svg',exptype,datatypes{datai,1}),'svg');
% end
% 
% %% 
% % for datai = 1:ndatatypes,
% %   set(hfigs(datai),'Renderer','painters');
% %   %savefig(hfigs(datai),sprintf('FlyBubble_GTTrackingError_TrainingTime_%s.fig',datatypes{datai,1}),'compact');
% %   saveas(hfigs(datai),sprintf('FlyBubble_GTTrackingError_TrainingTime_%s.svg',datatypes{datai,1}),'svg');
% % end
% 
% close all;
% 
% %% plot stats as a function of training time -prctiles only
% 
% 
% max_train_time = max(train_time(:));
% %patchr = min(pdist(train_time(:)));
% patchr = max_train_time /100;
% dx = [-1,1,1,-1,-1]*patchr;
% dy = [0,0,1,1,0];
% 
% hfigs = gobjects(1,ndatatypes);
% doplotnet = ~ismember(nets,{'cpropt','cprqck'});
% %doplotnet = ~ismember(nets,{'cprqck'});
% 
% for datai = ndatatypes:-1:1,
% 
%   hfigs(datai) = figure;
%   clf;
%   
%   set(hfigs(datai),'Position',[10,10,2526/2,(150+1004/4*nlabeltypes)/2]);
%   %set(hfigs(datai),'Position',[10,10,2526,1154]);
%   hax = createsubplots(nlabeltypes,npttypes,[[.025,.005];[.05,.005]]);
%   hax = reshape(hax,[nlabeltypes,npttypes]);
%   
%   for labeli = 1:nlabeltypes,
%   
%     for pti = 1:npttypes,
%   
%       axes(hax(labeli,pti));
%   
%       hold on;
% 
%       maxfrac = max(max(max(errfrac(:,:,:,pti,labeli,datai))));
%       
%       h = gobjects(1,nnets);
%       hprcs = gobjects(1,nprcs);
%       for ndx = 1:nnets,
%         if ~doplotnet(ndx),
%           continue;
%         end
%           
%         for mndx = 2:n_models
%           offx = train_time(ndx,mndx-1);
%           if numel(gtdata_size.(nets{ndx})) < mndx,
%             break;
%           end
%           
%           for prci = nprcs:-1:1,
%             colorfrac = colorfracprcs(prci);
%             tmp = [0,errprctiles(prci,ndx,mndx-1,pti,labeli,datai)];
%             patch(offx+dx,tmp(1+dy),colors(ndx,:)*colorfrac + 1-colorfrac,'EdgeColor',colors(ndx,:));
%           end
%       
%         end
%         if labeli == 1 && pti == 1,
%           h(ndx) = patch(nan(size(dx)),nan(size(dx)),colors(ndx,:),'LineStyle','none');
%         end
%       end
%       %set(gca,'XTick',1:n_models-1,'XTickLabels',num2str(n_train(:)));
%   
%       if pti == 1 && labeli == 1,
%         hprcs = gobjects(1,nprcs);
%         for prci = 1:nprcs,
%           hprcs(prci) = patch(nan(size(dx)),nan(size(dx)),[1,1,1]-colorfracprcs(prci),'EdgeColor','k');
%         end
%         legend([h(doplotnet),hprcs],[legendnames(doplotnet),arrayfun(@(x) sprintf('%d %%ile',x),prcs,'Uni',0)]);
%       end
%       if labeli == nlabeltypes,
%         xlabel('Training time (h)');
%       end
%       if pti == 1,
%         ylabel(labeltypes{labeli,1});
%       end
%       if labeli == 1,
%         title(pttypes{pti,1},'FontWeight','normal');
%       end
%       set(gca,'XLim',[min(train_time(:))-3*patchr,max(train_time(:))+3*patchr],'YLim',[0,maxerrplus]);
%       drawnow;
%     end
%     set(hax(:,2:end),'YTickLabel',{});
%     set(hax(1:end-1,:),'XTickLabel',{});
%     
%   end
%   set(hfigs(datai),'Name',datatypes{datai,1});
%   
%   set(hfigs(datai),'Renderer','painters');
%   %savefig(hfigs(datai),sprintf('FlyBubble_GTTrackingError_TrainingTime_%s.fig',datatypes{datai,1}),'compact');
%   break;
%   saveas(hfigs(datai),fullfile(savedir,sprintf('%s_GTTrackingError_TrainingTime_Prctiles_%s.svg',exptype,datatypes{datai,1})),'svg');
% end


% %% compute err again only for last entry
% 
% 
% gtdata = load(gtfile_trainsize);
% if ~isempty(gtfile_trainsize_cpr),
%   gtdata_cpr = load(gtfile_trainsize_cpr);
% end
% newfns = setdiff(fieldnames(gtdata_cpr),fieldnames(gtdata));
% for i = 1:numel(newfns),
%   gtdata.(newfns{i}) = gtdata_cpr.(newfns{i});
% end
% % 
% % gtdata = load(gtfile_trainsize);
% 
% %nets = fieldnames(gtdata);
% npts = size(gtdata.mdn{1}.labels,2);
% errfrac = nan([nbins,nnets,1,npts,nlabeltypes,ndatatypes]);
% errprctiles = nan([nprcs,nnets,1,npttypes,nlabeltypes,ndatatypes]);
% errprctilespts = nan([nprcs,nnets,1,npts,nlabeltypes,ndatatypes]);
% ndatapts = nan([nnets,1,npttypes,nlabeltypes,ndatatypes]);
% 
% maxdist = nan([nprcs,nnets,nlabeltypes,ndatatypes]);
% mindist = nan([nprcs,nnets,nlabeltypes,ndatatypes]);
% mediandist = nan([nprcs,nnets,nlabeltypes,ndatatypes]);
% 
% plottype = 'prctiles';
% prccolors = flipud(jet(100));
% prccolors = prccolors(round(linspace(1,100,nprcs)),:);
% 
% nerrthresh = 1000;
% errthresh = linspace(0,maxerr,nerrthresh);
% worstfracinliers = nan([nerrthresh,nnets,nlabeltypes,ndatatypes]);
% medianfracinliers = nan([nerrthresh,nnets,nlabeltypes,ndatatypes]);
% bestfracinliers = nan([nerrthresh,nnets,nlabeltypes,ndatatypes]);
% 
% for ndx = 1:nnets,
%   mndx = numel(gtdata.(nets{ndx}));
%   cur_data = gtdata.(nets{ndx}){mndx};
%   preds = cur_data.pred;
%   labels = cur_data.labels;
%   assert(size(preds,3)==2);
%   assert(size(labels,3)==2);
%   iscpr = ~isempty(strfind(nets{ndx},'cpr'));
% 
%   for datai = 1:ndatatypes,
%     dtis = datatypes{datai,2};
%     for labeli = 1:nlabeltypes,
%       ltis = labeltypes{labeli,2};
%       idx = ismember(conddata.data_cond,dtis) & ismember(conddata.label_cond,ltis);
%       if iscpr && isshexp,
%         % special case for SH/cpr whose computed GT output only has
%         % 1149 rows instead of 1150 cause dumb
%         idx(4) = [];
%       end
%       
%       for typei = 1:npttypes,
%         %ptis = typei;
%         ptis = pttypes{typei,2};
%         dist = sqrt(sum( (preds(idx,ptis,:)-labels(idx,ptis,:)).^2,3));
%         counts = hist(dist(:),bincenters);
%         ndatapts(ndx,1,typei,labeli,datai) = sum(counts);
%         errfrac(:,ndx,1,typei,labeli,datai) = counts;
%         errprctiles(:,ndx,1,typei,labeli,datai) = prctile(dist(:),prcs);
%       end
%       
%       for pti=1:npts
%         dist = sqrt(sum( (preds(idx,pti,:)-labels(idx,pti,:)).^2,3));
%         errprctilespts(:,ndx,1,pti,labeli,datai) = prctile(dist(:),prcs);        
%       end
%       
%       dist = sqrt(sum( (preds(idx,:,:)-labels(idx,:,:)).^2,3));
%       maxdistcurr = max(dist,[],2);
%       mediandistcurr = median(dist,2);
%       mindistcurr = min(dist,[],2);
%       maxdist(:,ndx,labeli,datai) = prctile(maxdistcurr(:),prcs);
%       mediandist(:,ndx,labeli,datai) = prctile(mediandistcurr(:),prcs);
%       mindist(:,ndx,labeli,datai) = prctile(mindistcurr(:),prcs);
%       % this is not optimal, but fast enough, not worth being smarter
%       ncurr = numel(maxdistcurr);
%       for i = 1:nerrthresh,
%         worstfracinliers(i,ndx,labeli,datai) = nnz(maxdistcurr <= errthresh(i)) / ncurr;
%         bestfracinliers(i,ndx,labeli,datai) = nnz(mindistcurr <= errthresh(i)) / ncurr;
%         medianfracinliers(i,ndx,labeli,datai) = nnz(mediandistcurr <= errthresh(i)) / ncurr;
%       end
%       
%     end
%   end
% end


%% compare algorithms per part

% offs = linspace(-.3,.3,nnets);
% doff = offs(2)-offs(1);
% dx = [-1,1,1,-1,-1]*doff/2;
% dy = [0,0,1,1,0];
% 
% hfigs = gobjects(1,ndatatypes);
% maxerrplus = maxerr*1.05;
% 
% for datai = ndatatypes:-1:1,
% 
%   hfigs(datai) = figure;
%   clf;
%   set(hfigs(datai),'Position',[10,10,150+(2080-150)/4*nlabeltypes,520]);
%   hax = createsubplots(1,nlabeltypes,[[.025,.005];[.05,.005]]);
%   hax = reshape(hax,[1,nlabeltypes]);
%   
%   for labeli = 1:nlabeltypes,
%     axes(hax(labeli));
%     hold on;
%   
%     h = gobjects(1,nnets);
%     for pti = 1:npttypes,
%       maxfrac = max(max(max(errfrac(:,:,:,pti,labeli,datai))));
%       
%       hprcs = gobjects(1,nprcs);
%       for ndx = 1:nnets,
%         %mndx = numel(gtdata.(nets{ndx}));
%         mndx = 2;
%         offx = pti + offs(ndx);
%         for bini = 1:nbins,
%           colorfrac = min(1,errfrac(bini,ndx,mndx-1,pti,labeli,datai)/maxfrac);
%           if colorfrac == 0,
%             continue;
%           end
%           patch(offx+dx,binedges(bini+dy),colors(ndx,:)*colorfrac + 1-colorfrac,'LineStyle','none');
%         end
%         for prci = 1:nprcs,
%           hprcs(prci) = plot(offx,min(maxerrplus,errprctiles(prci,ndx,mndx-1,pti,labeli,datai)),'w','MarkerFaceColor',colors(ndx,:),'Marker',markers{prci});
%         end
%         if pti == 1,
%           h(ndx) = patch(nan(size(dx)),nan(size(dx)),colors(ndx,:),'LineStyle','none');
%         end
%       end
%     end
%     
%     set(gca,'XTick',1:npttypes,'XTickLabels',pttypes,'XtickLabelRotation',45);
%   
%     if labeli == 1,
%       legend([h,hprcs],[nets,arrayfun(@(x) sprintf('%d %%ile',x),prcs,'Uni',0)]);
%     end
%     if labeli == 1,
%       ylabel('Error (px)');
%     end
%     title(labeltypes{labeli,1},'FontWeight','normal');
%     set(gca,'XLim',[0,npttypes+1],'YLim',[0,maxerrplus]);
%     drawnow;
%   end
%   set(hax(2:end),'YTickLabel',{});
%   
%   set(hfigs(datai),'Name',datatypes{datai,1});
%   set(hfigs(datai),'Renderer','painters');
%   %savefig(hfigs(datai),sprintf('FlyBubble_GTTrackingError_TrainingSetSize_%s.fig',datatypes{datai,1}),'compact');
%   saveas(hfigs(datai),sprintf('%s_GTTrackingError_FinalHist_%s.svg',exptype,datatypes{datai,1}),'svg');
% 
% end
