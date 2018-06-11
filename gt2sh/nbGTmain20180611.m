%% PRE-AND-DURING-SH-LABEL-CHECKING

lbl = load('gtsh_main_1150_v1_20180605_SJHcopy_050618_1731.lbl','-mat');
kb = load('SelectedGTFrames_SJH_20180603.mat');
%%
tGT = kb.frames2label;
tfIntra = strcmp(tGT.type,'intra');
nIntra = nnz(tfIntra);
iIntra = find(tfIntra);
intraOK = false(nIntra,1);
for jIntra=1:nIntra
  i = iIntra(jIntra);
  tGTrow = tGT(i,:);
  tf = strcmp(tGTrow.movFile(:,1),tGT.movFile(:,1)) & ...
       strcmp(tGTrow.movFile(:,2),tGT.movFile(:,2)) & ...
       tGTrow.frm==tGT.frm;
  typeVals = tGT(tf,:).type
  assert(nnz(tf)==2);
  assert(nnz(strcmp(typeVals,'intra'))==1);
end

%%
tGT(tfIntra,:).movFile = cellfun(@intraizeMovie,tGT(tfIntra,:).movFile,'uni',0);
tGT.movFile = regexprep(tGT.movFile,'\\','/');
tGT = tGT(:,{'movFile' 'frm'});
tGT.Properties.VariableNames = {'mov' 'frm'};
tGT.iTgt = ones(height(tGT),1);
tGT = sortrows(tGT,{'mov' 'frm'},{'ascend' 'ascend'});

%%
tLbl = lbl.gtSuggMFTable;
mfagt = lbl.movieFilesAllGT;
iMov = abs(tLbl.mov);
movfiles = mfagt(iMov,:);
movfiles = regexprep(movfiles,'\$flpCE','/groups/huston/hustonlab/flp-chrimson_experiments');
tLbl.mov = movfiles;
tLbl = sortrows(tLbl,{'mov' 'frm'},{'ascend' 'ascend'});

isequal(tGT,tLbl)

%%
fly2dlt = readtable('z:/apt/experiments/data/fly2DLT_lookupTableAL_win.csv','Delimiter',',');
mfafgt = lbl.movieFilesAllGT;
mfafgt = regexprep(mfafgt,'\$flpCE','/groups/huston/hustonlab/flp-chrimson_experiments');
nmfaf = size(mfafgt,1);
for i=1:nmfaf
  tf = strcmp(mfafgt{i,1},tGT.movFile(:,1));  
  flyID = unique(tGT(tf,:).flyID);
  assert(isscalar(flyID));
  iCalib = find(flyID==fly2dlt.fly);
  assert(isscalar(iCalib));
  calfile = fly2dlt.calibfile{iCalib};
  calfile = regexprep(calfile,'Z:/','\\\\dm11.hhmi.org\\hustonlab\\');
  cal1 = lbl.viewCalibrationDataGT{i};
  cal2 = CalRig.loadCreateCalRigObjFromFile(calfile);
  if isa(cal1,'CalRigSH')
    assert(isequal(cal1.kineData,cal2.kineData));
  elseif isa(cal1,'OrthoCamCalPair')
    assert(isequal(cal1.rvecs,cal2.rvecs));
  end
  disp(i);
end

%%
lbl = load('gtsh_main_1150_v1_20180605_SJHcopy_060618_0941.lbl','-mat');
%%
hFig = figure;
axs = createsubplots(1,2);
hold(axs(1),'on');
hold(axs(2),'on');
axis(axs(1),'ij');
axis(axs(2),'ij');
lposgt = lbl.labeledposGT;
clrs = lines(5);
markers = {'s' 's' 'o' 'o' 'v'};
for i=1:numel(lposgt)
  lpos = lposgt{i};
  lpos = SparseLabelArray.full(lpos);
  f = frameLabeled(lpos);
  nf = numel(f);
  fprintf(1,'mov gtmov %d. %d frms lbled.\n',i,nf);
  for iF=1:nf
    xy = lpos(:,:,f(iF),1);
    for ipt=1:5
      plot(axs(1),xy(ipt,1),xy(ipt,2)','.','markersize',8,'markerfacecolor',clrs(ipt,:),'marker',markers{ipt});
      plot(axs(2),xy(ipt+5,1),xy(ipt+5,2),'.','markersize',8,'markerfacecolor',clrs(ipt,:),'marker',markers{ipt});
    end
    nnnan = sum(~isnan(xy(:)));    
    if nnnan~=20
      fprintf(2,'  frame idx %d. nnnan=%d\n',iF,nnnan);
    end      
  end
end

%%
mfts = MFTSetEnum.AllMovAllLabeled;
tGTLbled = mfts.getMFTable(lObj);
wbObj = WaitBarWithCancel('foo');
tGTLbled = Labeler.labelAddLabelsMFTableStc(tGTLbled,lObj.labeledposGT,...
  lObj.labeledpostagGT,lObj.labeledposTSGT,'wbObj',wbObj);
%%
tGTLbled.err = zeros(height(tGTLbled),1);
tGTLbled.pTrk = tGTLbled.p;
tGTLbled.pLbl = tGTLbled.p;
lObj.trackLabelMontage(tGTLbled,'err');
%%
tGTsugg = lObj.gtSuggMFTable;
%%
mfaf = lObj.movieFilesAllGTFull;
for i=1:height(tGTLbled)
  trow = tGTLbled(i,:);
  iMov = abs(trow.mov);
  movs = mfaf(iMov,:);
  [m1P,m1F,m1E] = fileparts(movs{1});
  [m2P,m2F,m2E] = fileparts(movs{2});
  if strcmp(m1F(end-1:end),'_i')
    m1F = m1F(1:end-2);
  end
  if strcmp(m2F(end-1:end),'_i')
    m2F = m2F(1:end-2);
  end
  trk1 = fullfile(m1P,[m1F '.trk']);
  trk2 = fullfile(m2P,[m2F '.trk']);
  trk1 = load(trk1,'-mat');
  trk2 = load(trk2,'-mat');
  
  pTrkComb = cat(1,trk1.pTrk,trk2.pTrk);
  pTrk = pTrkComb(:,:,trow.frm);
  pLbl = reshape(trow.p,[10 2]);
  err = mean(sqrt(sum((pTrk-pLbl).^2,2)));
  tGTLbled.pTrk(i,:) = pTrk(:);
  tGTLbled.err(i) = err;
  fprintf('%d: %.3f\n',i,err);
end
%% END PRE-AND-DURING-SH-LABEL-CHECKING



%%
FLYNUM2BA = 'f:\repo\apt4\user\flynum2bodyAxis.csv';
f2ba = readtable(FLYNUM2BA);
f2ba.Properties.VariableNames = {'fly' 'lbl' 'mov' 'frm' 'calib'};

%% Figure out if all training data has bodyAxis labels.
[tf,loc] = ismember(tMain20180503.flyID,f2ba.fly);
nnz(tf)
%%
tBig = 'W:\apt\experiments\data\shflies20180518.csv';
tBig = readtable(tBig);
flyCalib = tBig.fly(tBig.isBodyAxis==1);

% Conc: Can't use bodyAxis points b/c 21 training flies don't have bodyAxis 
% data. Would also need to figure out how to use BA data in view1, b/c the
% next points are not the center-of-roi for side-view labels.

%% 
gtStuff = load('SelectedGTFrames_SJH_20180603.mat');
%%
tf = ismember(gtStuff.frames2label.flyID,f2ba.fly);
flyNoCalib = unique(gtStuff.frames2label.flyID(~tf))

% Odd, even GT table has a fly (382) that doesn't have BA data.

%%
ci = load('f:\aptStephenCPRInvestigate20180327\cropInfo20180426.mat');
%%
tf = ismember(gtStuff.frames2label.flyID,ci.t.fly);
flyGTBeenClicked = unique(gtStuff.frames2label.flyID(tf))
flyGTNotClicked = unique(gtStuff.frames2label.flyID(~tf))

% most GT flies have not been clicked.

%% Review existing clicks
unFly = unique(ci.t.fly);
for i=1:numel(unFly)
  tfFly = ci.t.fly==unFly(i);
  cpts = ci.cpts(tfFly,:,:);
  cpts = reshape(cpts,nnz(tfFly),4);
  fprintf(1,'Fly %d. %d movs. %d clicks\n',unFly(i),nnz(tfFly),...
    size(unique(cpts,'row'),1));
end

% Out of 99 training flies, 2 (26 and 441) have more than 1 clickpt.

%%
tMainTmp = tMain20180503(:,{'flyID'});
tMainTmp.Properties.VariableNames = {'fly'};
tMainTmp.mov1 = tMain20180503.movFile_read(:,1);
tMainTmp.mov2 = tMain20180503.movFile_read(:,2);
tf = ismember(tMainTmp,ci.t);
all(tf)
size(unique(tMainTmp,'rows'))
%% OK so the plan is:
% 1. Review existing click positions so I remember how I clicked, plus how
% the little UI works.
% 2. Click for the 70 GT flies that haven't been clicked.
% 3. (maybe opt) Check the 2 training movies that got clicked multiple times 
% and reduce to 1 per fly.
% 3.5. Browse all GT rows with their clicks; including rows for flies that
% already had clicks.
% 4. Use the clicks to generate the crops, check nbCrop2.
% 5. Save the new clicks and crops to the apt folder.
% 6. (if we did opt thing) Tell Mayank in case he wants to retrain based on
% the very slightly changed crops.
% 7. Create the GT cropped dataset.
% 8. Full train on training set
% 9. Track on GT set

%% 1. Review
movCrop(ci.t,ci.I1,ci.cpts)
%% 2a. find unique (fly,mov1,mov2)
tGT = gtStuff.frames2label(:,{'flyID'});
tGT.Properties.VariableNames = {'fly'};
tGT.mov1 = gtStuff.frames2label.movFile(:,1);
tGT.mov2 = gtStuff.frames2label.movFile(:,2);
tGT = unique(tGT,'rows');
tGT.mov1 = regexprep(tGT.mov1,'/groups/huston/hustonlab/','Z:/');
tGT.mov2 = regexprep(tGT.mov2,'/groups/huston/hustonlab/','Z:/');
%% 2b. for each row of tGT, get the first frame of mov1 and mov2
nGT = height(tGT);
Igt = cell(nGT,1);
mr = MovieReader;
mr.forceGrayscale = true;
for i=1:nGT
  movs = {tGT.mov1{i} tGT.mov2{i}};
  for ivw=1:2
    mr.open(movs{ivw});
    Igt{i,ivw} = mr.readframe(1);
  end
  disp(i);
end
%%
save cropInfoGT20180611.mat tGT Igt;

%%
tfNotClicked = ismember(tGT.fly,flyGTNotClicked);
all(ismember(tGT.fly(~tfNotClicked),flyGTBeenClicked))
tGTNotClicked = tGT(tfNotClicked,:);
IgtNotClicked = Igt(tfNotClicked,:);
size(tGTNotClicked)
%% 2c. click 
movCrop(tGTNotClicked,IgtNotClicked);
% saved to cropInfoGT20180611.mat

%% 2.5. One fly in tGTNotClicked had two movs with diff clickpts.
ciGT = load('cropInfoGT20180611.mat');
flyUn = unique(tGTNotClicked.fly);
for i=1:numel(flyUn)
  fly = flyUn(i);
  tffly = fly==tGTNotClicked.fly;
  nrow = nnz(tffly);
  cptsthis = reshape(ci.cpts(tffly,:,:),nrow,4);
  cptsthis = unique(cptsthis,'rows');
  if nrow>1 
    fprintf('fly %d: %d rows\n',fly,nrow);
    if size(cptsthis,1)>1
      fprintf('... Taking average\n');
      cptsthis = mean(cptsthis,1);
      cptsthis = repmat(cptsthis,nrow,1);
      cptsthis = reshape(cptsthis,nrow,2,2);
      ci.cpts(tffly,:,:) = cptsthis;
    end
  end    
end
%%
save('cropInfoGT20180611.mat','-struct','ci');
%%
movCrop(ci.tGTNotClicked,ci.IgtNotClicked,ci.cpts);

%% 3.5 Giant Montage showing clicked pts
ci0 = load('f:\aptStephenCPRInvestigate20180327\cropInfo20180426.mat');
ciGT = load('cropInfoGT20180611.mat');
%%
% two montages, vw1 and vw2
% for each fly in tGT
% - find if in 201806 or 201804 crop. take note
% - show im for each view. truesize
% - plot clicked pt.
% - text label, flyID

DOSAVE = false;
SAVEDIR = fullfile(pwd,'figs');

NR = 9;
NC = 10;
GTMRKER = '.';
GTCOLOR = [255 127 80]/255;
GTMRKRSZ = 10;
TRNCOLOR = [57 255 20]/255;
GTPLOTARGS = {GTMRKER,'color',GTCOLOR,'markersize',GTMRKRSZ};
TRNPLOTARGS = {GTMRKER,'color',TRNCOLOR,'markersize',GTMRKRSZ};
TXTYPOS = 20;

hFig(1) = figure(11);
set(hFig(1),'Position',[2561 401 1920 1124]);
axs{1} = createsubplots(NR,NC,0);
axs{1} = reshape(axs{1},NR,NC);
hFig(2) = figure(12);
set(hFig(2),'Position',[2561 401 1920 1124]);
axs{2} = createsubplots(NR,NC,0);
axs{2} = reshape(axs{2},NR,NC);
tGT = ciGT.tGT;
nGT = height(tGT);
for i=1:nGT
  fly = tGT.fly(i);
  tf0 = ci0.t.fly==fly;
  tf1 = ciGT.tGTNotClicked.fly==fly;
  assert(xor(any(tf0),any(tf1)));
  if any(tf0)
    nrow = nnz(tf0); 
    cpts = ci0.cpts(tf0,:,:);
    irow1 = find(tf0,1);
    ims = ci0.I1(irow1,:);
    tfTrnClick = true;
  else
    nrow = nnz(tf1);
    cpts = ciGT.cpts(tf1,:,:);
    irow1 = find(tf1,1);
    ims = ciGT.IgtNotClicked(irow1,:);
    tfTrnClick = false;
  end
  cpts = reshape(cpts,nrow,4);
  cpts = unique(cpts,'rows');
  cpts = reshape(cpts,2,2); % {x/y},view
  for ivw=1:2
    ax = axs{ivw}(i);
    axes(ax);
    ax.Color = [0 0 0];
    imagesc(ims{ivw});
    hold on;
    colormap gray
    axis ij;
    tstr = sprintf('fly%03d',fly);
    if tfTrnClick
      plot(cpts(1,ivw),cpts(2,ivw),TRNPLOTARGS{:});
      text(1,TXTYPOS,tstr,'color',TRNCOLOR);
    else
      plot(cpts(1,ivw),cpts(2,ivw),GTPLOTARGS{:});
      text(1,TXTYPOS,tstr,'color',GTCOLOR);
    end
    %grid on;
    set(ax,'XTick',[],'YTick',[]);
  end
end

if DOSAVE
  for ivw=1:2
    hFig(ivw).InvertHardcopy = 'off';
    FNAME = sprintf('clickPts_vw%d',ivw);
    hgsave(hFig(ivw),fullfile(SAVEDIR,[FNAME '.fig']));
    set(hFig(ivw),'PaperOrientation','landscape','PaperType','arch-c');
    print(hFig(ivw),'-dpdf',fullfile(SAVEDIR,[FNAME '.pdf']));
    print(hFig(ivw),'-dpng','-r300',fullfile(SAVEDIR,[FNAME '.png']));
  end
end

%% 4. Use the clicks to generate the crops, check nbCrop2.
%% 4a. Compile inputs:
% - IgtMain. [nGTmainx2] cell array of raw images for GT rows.
% - xyLblGTMain. [nGTmainx5x2x2] gt labels. {iGT,ipt,x/y,iview}.
% - tGTMain. [nGTmain x ncol] gt metadata.
% - cptsGT. [nGTmainx2x2]. clicked points for GT rows. {iGT,{x,y},vw}

% -now have tGTMain, IgtMain. 
% - use labelAddLabelsMFTableStc, then pLbl2xyblah to get xyLblGTMain.
% - compile cptsGT

gtStuff = load('SelectedGTFrames_SJH_20180603.mat');
tGTMain = gtStuff.frames2label;
tGTMain.mov = regexprep(tGTMain.movFile,'/groups/huston/hustonlab/','Z:/');
IgtMain = MFTable.fetchImages(tGTMain);

%%

IToCrop = IFinalReconciled;
xyLblToCrop = xyLbl;
tToCrop = tFinalReconciled;
n = height(tToCrop);
szassert(IToCrop,[n 2]);
szassert(xyLblToCrop,[n 5 2 2]);

JITTER_RC = [28 8.5; 29.5 20]; % ivw, {nr,nc}.  based on SDs of 1D distros of delCCPcents
%JITTER_RC = [0 0;0 0]; 
ROI_NRNC = [350 230; 350 350]; % ivw, {nr,nc}
xyCCP = reshape(tToCrop.cropClickPts,n,2,2); % row,{x,y},iVw

IFR_crop3 = cell(size(IToCrop));
xyLbl_FR_crop3 = nan(size(xyLblToCrop));
roi_crop3 = nan(n,4,2); % irow,{xlo,xhi,ylo,yhi},ivw
crop3_xyjitterappld = nan(n,2,2); % irow,{x,y},ivw
