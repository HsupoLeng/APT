classdef PreProcDB < handle
  % Preprocessed DB for DL
  % We are forking this off the CPR/old .preProcData stuff in Labeler b/c
  % i) 
  
  properties 
    dat % CPRData scalar
    tsLastEdit % last edit timestamp
  end
  
  methods
    
    function obj = PreProcDB()
    end
    
    function init(obj)
      I = cell(0,1);
      tblP = MFTable.emptyTable(MFTable.FLDSCORE);
      obj.dat = CPRData(I,tblP);
      obj.tsLastEdit = now;
    end
        
    function tblNewReadFailed = add(obj,tblNew,lObj,varargin)
      % Add new rows to DB
      %
      % tblNew: new rows. MFTable.FLDSCORE are required fields. .roi may 
      %   be present and if so WILL BE USED to grab images and included in 
      %   data/MD. Other fields are ignored.
      %   IMPORTANT: if .roi is present, .p (labels) are expected to be 
      %   relative to the roi.
      %
      % tblNewReadFailed: table of failed-to-read rows. Currently subset of
      %   tblNew. If non-empty, then .dat was not updated with these rows 
      %   as requested.
      
      [wbObj,prmpp] = myparse(varargin,...
        'wbObj',[],...
        'prmpp',[]... % preprocessing params
        );

      tfWB = ~isempty(wbObj);
      if isempty(prmpp)
        prmpp = lObj.preProcParams;
        if isempty(prmpp)
          error('Please specify preprocessing parameters.');
        end
      end
      
      assert(isstruct(prmpp),'Expected parameters to be struct/value class.');

      FLDSREQUIRED = MFTable.FLDSCORE;
      FLDSALLOWED = [MFTable.FLDSCORE {'roi' 'nNborMask'}];
      tblfldscontainsassert(tblNew,FLDSREQUIRED);
      
      currMD = obj.dat.MD;
      tf = tblismember(tblNew,currMD,MFTable.FLDSID);
      nexists = nnz(tf);
      if nexists>0
        error('%d rows of tblNew exist in current db.',nexists);
      end
      
      tblNewReadFailed = tblNew([],:);
      
      if prmpp.histeq
        warningNoTrace('Histogram Equalization currently disabled for Deep Learning trackers.');
        prmpp.histeq = false;
      end
      if prmpp.BackSub.Use
        warningNoTrace('Background subtraction currently disabled for Deep Learning trackers.');
        prmpp.BackSub.Use = false;
      end
      if prmpp.NeighborMask.Use
        warningNoTrace('Neighbor masking currently disabled for Deep Learning trackers.');
        prmpp.NeighborMask.Use = false;
      end
      assert(isempty(prmpp.channelsFcn));
                        
      tblNewConc = lObj.mftTableConcretizeMov(tblNew);
      nNew = height(tblNew);
      if nNew>0
        fprintf(1,'Adding %d new rows to data...\n',nNew);

        [I,nNborMask,didread] = CPRData.getFrames(tblNewConc,...
          'wbObj',wbObj,...
          'forceGrayscale',lObj.movieForceGrayscale,...
          'preload',lObj.movieReadPreLoadMovies,...
          'movieInvert',lObj.movieInvert,...
          'roiPadVal',prmpp.TargetCrop.PadBkgd,...
          'doBGsub',prmpp.BackSub.Use,...
          'bgReadFcn',prmpp.BackSub.BGReadFcn,...
          'bgType',prmpp.BackSub.BGType,...
          'maskNeighbors',prmpp.NeighborMask.Use,...
          'maskNeighborsMeth',prmpp.NeighborMask.SegmentMethod,...
          'maskNeighborsEmpPDF',lObj.fgEmpiricalPDF,...
          'fgThresh',prmpp.NeighborMask.FGThresh,...
          'trxCache',lObj.trxCache);
        if tfWB && wbObj.isCancel
          % obj unchanged
          return;
        end
        % Include only FLDSALLOWED in metadata to keep CPRData md
        % consistent (so can be appended)
        
        didreadallviews = all(didread,2);
        tblNewReadFailed = tblNew(~didreadallviews,:);
        tblNew(~didreadallviews,:) = [];
        I(~didreadallviews,:) = [];
        nNborMask(~didreadallviews,:) = [];
        
        % AL: a little worried if all reads fail -- might get a harderr
        
        tfColsAllowed = ismember(tblNew.Properties.VariableNames,FLDSALLOWED);
        tblNewMD = tblNew(:,tfColsAllowed);
        tblNewMD = [tblNewMD table(nNborMask)];
        
        dataNew = CPRData(I,tblNewMD);
        obj.dat.append(dataNew);
        
        obj.tsLastEdit = now;
      end      
    end
    
    function updateLabels(obj,tblUp,lObj,varargin)
      % Update rows, labels (pGT and tfocc) ONLY. images don't change!
      %
      % tblUp: updated rows (rows with updated pGT/tfocc).
      %   MFTable.FLDSCORE fields are required. Only .pGT and .tfocc are 
      %   otherwise used. Other fields ignored, INCLUDING eg .roi and 
      %   .nNborMask. Ie, you cannot currently update the roi of a row in 
      %   the cache (whose image has already been fetched)
      
      [prmpp,updateRowsMustMatch] = myparse(varargin,...
        'prmpp',[],... % preprocessing params
        'updateRowsMustMatch',false ... % if true, assert/check that tblUp matches current data
        );

      if isempty(prmpp)
        prmpp = lObj.preProcParams;
        if isempty(prmpp)
          error('Please specify preprocessing parameters.');
        end
      end

      dataCurr = obj.dat;
      
      nUpdate = size(tblUp,1);
      if nUpdate>0 % AL 20160413 Shouldn't need to special-case, MATLAB 
                   % table indexing API may not be polished
        [tf,loc] = tblismember(tblUp,dataCurr.MD,MFTable.FLDSID);
        assert(all(tf));
        if updateRowsMustMatch
          assert(isequal(dataCurr.MD{loc,'tfocc'},tblUp.tfocc),...
            'Unexpected discrepancy in preproc data cache: .tfocc field');
          if tblfldscontains(tblUp,'roi')
            assert(isequal(dataCurr.MD{loc,'roi'},tblUp.roi),...
              'Unexpected discrepancy in preproc data cache: .roi field');
          end
          if tblfldscontains(tblUp,'nNborMask')
            assert(isequal(dataCurr.MD{loc,'nNborMask'},tblUp.nNborMask),...
              'Unexpected discrepancy in preproc data cache: .nNborMask field');
          end
          assert(isequaln(dataCurr.pGT(loc,:),tblUp.p),...
            'Unexpected discrepancy in preproc data cache: .p field');
        else
          fprintf(1,'Updating labels for %d rows...\n',nUpdate);
          dataCurr.MD{loc,'tfocc'} = tblUp.tfocc; % AL 20160413 throws if nUpdate==0
          dataCurr.pGT(loc,:) = tblUp.p;
          % Check .roi, .nNborMask?
        end
        
        obj.tsLastEdit = now;
      end
    end

    function tblAddReadFailed = addAndUpdate(obj,tblAU,lObj,varargin)
      % Combo of add/updateLabels
      %
      % tblAU: ("tblAddUpdate")
      %   - MFTable.FLDSCORE: required.
      %   - .roi: optional, USED WHEN PRESENT. (prob needs to be either
      %   consistently there or not-there for a given obj or initData()
      %   "session"
      %   IMPORTANT: if .roi is present, .p (labels) are expected to be 
      %   relative to the roi.
      %   - .pTS: optional (if present, deleted)
      
      [wbObj,updateRowsMustMatch,prmpp] = myparse(varargin,...
        'wbObj',[],... % WaitBarWithCancel. If cancel, obj unchanged.
        'updateRowsMustMatch',false,... % See updateLabels
        'prmpp',[] ...
        );
      
      [tblPnew,tblPupdate] = obj.dat.tblPDiff(tblAU);
      tblAddReadFailed = obj.add(tblPnew,lObj,'wbObj',wbObj,'prmpp',prmpp);
      obj.updateLabels(tblPupdate,lObj,'wbObj',wbObj,...
        'updateRowsMustMatch',updateRowsMustMatch);      
    end
    
  end
  
  methods (Static)    
    function fetchImages
      % Fetch images 
    end
  end

end