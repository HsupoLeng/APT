TTFILES = { ...
'trntrk_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_easy_fold01_tblTrn_hpo_outer3_easy_fold01_tblTst_prm0_20180713_20180716T150605.mat'
'trntrk_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_easy_fold01_tblTrn_hpo_outer3_easy_fold01_tblTst_prm1_20180714_20180716T151001.mat'
'trntrk_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_easy_fold01_tblTrn_hpo_outer3_easy_fold01_tblTst_prm2_20180715_20180716T151015.mat'
'trntrk_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_easy_fold01_tblTrn_hpo_outer3_easy_fold01_tblTst_prm3_20180716_20180717T065118.mat'
'trntrk_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_hard_fold01_tblTrn_hpo_outer3_hard_fold01_tblTst_prm0_20180713_20180716T151142.mat'
'trntrk_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_hard_fold01_tblTrn_hpo_outer3_hard_fold01_tblTst_prm1_20180714_20180716T151200.mat'
'trntrk_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_hard_fold01_tblTrn_hpo_outer3_hard_fold01_tblTst_prm2_20180715_20180716T151225.mat'
'trntrk_sh_trn4523_gt080618_made20180627_cacheddata_hpo_outer3_hard_fold01_tblTrn_hpo_outer3_hard_fold01_tblTst_prm3_20180716_20180717T065155.mat'
};

tt = cellfun(@load,TTFILES,'uni',0);

errE = cat(3,tt{1}.tblRes.dLblTrk,tt{2}.tblRes.dLblTrk,...
             tt{3}.tblRes.dLblTrk,tt{4}.tblRes.dLblTrk);
errH = cat(3,tt{5}.tblRes.dLblTrk,tt{6}.tblRes.dLblTrk,...
             tt{7}.tblRes.dLblTrk,tt{8}.tblRes.dLblTrk);

errE = reshape(errE,size(errE,1),5,2,4);
errH = reshape(errH,size(errH,1),5,2,4);

%% TrnTrk Eval
DOSAVE = true;
SAVEDIR = 'figs';
SETNAMES = {'Round1' 'Round2' 'Round3' 'Round4'};
PTILES = [50 75 90 95 97.5 99];

hFig = [];

hFig(end+1) = figure(11);
hfig = hFig(end);
set(hfig,'Name','easy','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurves(...
  errE,'hFig',hfig,...
  'setNames',SETNAMES,...
  'ptiles',PTILES,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize',16});

hFig(end+1) = figure(15);
hfig = hFig(end);
set(hfig,'Name','hard','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurves(...
  errH,'hFig',hfig,...
  'setNames',SETNAMES,...
  'ptiles',PTILES,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize',16});

hFig(end+1) = figure(20);
hfig = hFig(end);
set(hfig,'Name','hardno99','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.ptileCurves(...
  errH,'hFig',hfig,...
  'setNames',SETNAMES,...
  'ptiles',[50 75 90 95 97.5],...
  'axisArgs',{'XTicklabelRotation',90,'FontSize',16});

hFig(end+1) = figure(25);
hfig = hFig(end);
set(hfig,'Name','easybullseye','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.bullseyePtiles(errE,...
  td.IMain20180503_crop2(1,:),squeeze(td.xyLblMain20180503_crop2(1,:,:,:)),...
  'hFig',hfig,...
  'setNames',SETNAMES,...
  'ptiles',PTILES,...
  'lineWidth',2,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize',16});

hFig(end+1) = figure(30);
hfig = hFig(end);
set(hfig,'Name','hardbullseye','Position',[2561 401 1920 1124]);
[~,ax] = GTPlot.bullseyePtiles(errH,...
  td.IMain20180503_crop2(1,:),squeeze(td.xyLblMain20180503_crop2(1,:,:,:)),...
  'hFig',hfig,...
  'setNames',SETNAMES,...
  'ptiles',PTILES,...
  'lineWidth',2,...
  'axisArgs',{'XTicklabelRotation',90,'FontSize',16});

if DOSAVE
  for i=1:numel(hFig)
    h = figure(hFig(i));
    fname = h.Name;
    hgsave(h,fullfile(SAVEDIR,[fname '.fig']));
    set(h,'PaperOrientation','landscape','PaperType','arch-d');
    print(h,'-dpdf',fullfile(SAVEDIR,[fname '.pdf']));  
    print(h,'-dpng','-r300',fullfile(SAVEDIR,[fname '.png']));   
    fprintf(1,'Saved %s.\n',fname);
  end
end