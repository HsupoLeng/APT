classdef RegressorCascade < handle
  
  properties (SetAccess=private)
    % model/params
    prmModel 
    prmTrainInit
    prmReg 
    prmFtr 
  end
  
  properties
    pGTNTrn % [NtrnxD] normalized shapes used during most recent full training
    
    ftrSpecs % [nMjr] cell array of feature definitions/specifications. ftrSpecs{i} is either [], or a struct specifying F features
    %ftrs % [nMjr] cell array of instantiated features. ftrs{i} is either [], or NxF    
    ftrsUse % [nMjr x nMnr x M x nUse] selected feature subsets (M=fern depth). ftrsUse(iMjr,iMnr,:,:) contains selected features for given iteration. nUse is 1 by default or can equal 2 for ftr.metatype='diff'.        
    
    fernN % [nMjr x nMnr] total number of data points run through fern regression 
    fernMu % [nMjr x nMnr x D] mean output (Y) encountered by fern regression
    fernThresh % [nMjr x nMnr x M] fern thresholds
    fernCounts % [nMjr x nMnr x 2^M X D] count of number of shapes binned for each coord, treating NaNs as missing data
    fernSums % [nMjr x nMnr x 2^M X D] sum of dys for each bin/coord, treating NaNs as missing data
    fernOutput % [nMjr x nMnr x 2^M x D] output/shape correction for each fern bin
    fernTS % [nMjr x nMnr] timestamp last mod .fernCounts/Output
    
    trnLog % struct array, one el per train/retrain action
  end
  properties (Dependent)
    nMajor
    nMinor
    M
    mdld
    mdlD
    hasTrained % scalar logical; true if at least one full training has occurred
  end
  
  methods
    function v = get.nMajor(obj)
      v = obj.prmReg.T;
    end
    function v = get.nMinor(obj)
      v = obj.prmReg.K;
    end
    function v = get.M(obj)
      v = obj.prmReg.M;
    end
    function v = get.mdld(obj)
      v = obj.prmModel.d;
    end
    function v = get.mdlD(obj)
      v = obj.prmModel.D;
    end
    function v = get.hasTrained(obj)
      v = ~isempty(obj.trnLogMostRecentTrain());
    end
  end
  
  methods
    
    function obj = RegressorCascade(sPrm)
      % sPrm: parameter struct
      
      if isfield(sPrm.Model,'D')
        assert(sPrm.Model.D==sPrm.Model.d*sPrm.Model.nfids);
      else
        sPrm.Model.D = sPrm.Model.d*sPrm.Model.nfids;
      end
      obj.prmModel = sPrm.Model;
      obj.prmTrainInit = sPrm.TrainInit;
      obj.prmReg = sPrm.Reg;
      obj.prmFtr = sPrm.Ftr;  
      obj.init();
    end
    
    function init(obj,varargin)
      % Clear/init everything but mdl/params
      
      initTrnLog = myparse(varargin,...
        'initTrnLog',true); 
      
      obj.pGTNTrn = [];
      
      nMjr = obj.nMajor;
      nMnr = obj.nMinor;
      MM = obj.M;
      ftrMetaType = obj.prmFtr.metatype;
      switch ftrMetaType
        case 'single'
          nUse = 1;
        case 'diff'
          nUse = 2;
        otherwise
          assert(false);
      end      
      
      obj.ftrSpecs = cell(nMjr,1);
      obj.ftrsUse = nan(nMjr,nMnr,MM,nUse);
      
      obj.fernN = zeros(nMjr,nMnr);
      obj.fernMu = nan(nMjr,nMnr,obj.mdlD);    
      obj.fernThresh = nan(nMjr,nMnr,MM);
      obj.fernSums = zeros(nMjr,nMnr,2^MM,obj.mdlD);
      obj.fernCounts = zeros(nMjr,nMnr,2^MM,obj.mdlD);
      obj.fernOutput = nan(nMjr,nMnr,2^MM,obj.mdlD);
      obj.fernTS = -inf*ones(nMjr,nMnr);
      
      if initTrnLog
        obj.trnLogInit();
      end
    end
    
    function [ftrs,iFtrs] = computeFeatures(obj,t,I,bboxes,p,pIidx,tfused) % obj const
      % t: major iteration
      % I: [N] Cell array of images
      % bboxes: [Nx2*d]
      % p: [QxD] shapes, absolute coords.
      % pIidx: [Q] indices into I for rows of p
      % tfuse: if true, only compute those features used in obj.ftrsUse(t,:,:,:)
      %
      % ftrs: If tfused==false, then [QxF]; otherwise [QxnUsed]
      % iFtrs: feature indices labeling cols of ftrs
      
      fspec = obj.ftrSpecs{t};

      if tfused
        iFtrs = obj.ftrsUse(t,:,:,:);
        iFtrs = unique(iFtrs(:));
      else
        iFtrs = 1:fspec.F;
        iFtrs = iFtrs(:);
      end        
      
      assert(~isempty(fspec),'No feature specifications for major iteration %d.',t);
      switch fspec.type
        case 'kborig_hack'
          assert(~tfused,'Unsupported.');
          ftrs = shapeGt('ftrsCompKBOrig',obj.prmModel,p,I,fspec,...
            pIidx,[],bboxes,obj.prmReg.occlPrm);
        case {'1lm' '2lm' '2lmdiff'}
          fspec = rmfield(fspec,'pids');
          fspec.F = numel(iFtrs);
          fspec.xs = fspec.xs(iFtrs,:);
          ftrs = shapeGt('ftrsCompDup2',obj.prmModel,p,I,fspec,...
            pIidx,[],bboxes,obj.prmReg.occlPrm);
        otherwise
          assert(false,'Unrecognized feature specification type.');
      end
    end
    
    function trainWithRandInit(obj,I,bboxes,pGT,varargin)
      initpGTNTrn = myparse(varargin,...
        'initpGTNTrn',false... % if true, init with .pGTNTrn rather than pGT
        );
      
      tiPrm = obj.prmTrainInit;
      if initpGTNTrn
        N = numel(I);
        Naug = tiPrm.Naug;        
        pGTTrnNMu = nanmean(obj.pGTNTrn,1);
        model = obj.prmModel;
        
        p0 = Shape.randInitShapes(pGTTrnNMu,Naug,model,bboxes,...
          'dorotate',tiPrm.augrotate); % [NxNaugxD]
        p0 = reshape(p0,[N*Naug model.D]);
        pIidx = repmat(1:N,[1 Naug])'; 
      else
        [p0,~,~,~,pIidx] = shapeGt('initTr',[],pGT,obj.prmModel,[],bboxes,...
          tiPrm.Naug,tiPrm.augpad,tiPrm.augrotate);
      end
      
      obj.train(I,bboxes,pGT,p0,pIidx,varargin{:});
    end
    
    function pAll = train(obj,I,bboxes,pGT,p0,pIidx,varargin)
      % 
      %
      % I: [N] cell array of images
      % bboxes: [Nx2*d]
      % pGT: [NxD] GT labels (absolute coords)
      % p0: [QxD] initial shapes (absolute coords).
      % pIidx: [Q] indices into I
      %
      % pAll: [QxDxT+1] propagated training shapes (absolute coords)
      
      [verbose,hWB,update] = myparse(varargin,...
        'verbose',1,...
        'hWaitBar',[],...
        'update',false... % if true, incremental update
        );
      
      NI = numel(I);
      assert(isequal(size(bboxes),[NI 2*obj.mdld]));
      assert(isequal(size(pGT),[NI obj.mdlD]));      
      [Q,D] = size(p0);
      assert(D==obj.mdlD);
      assert(numel(pIidx)==Q);
      
      if update && ~obj.hasTrained
        error('RegressorCascade:noTrain',...
          'Cannot perform incremental train without first doing a full train.');
      end

      model = obj.prmModel;
      pGTFull = pGT(pIidx,:);
      T = obj.nMajor;
      pAll = zeros(Q,D,T+1);
      pAll(:,:,1) = p0;
      t0 = 1;
      pCur = p0;
      bboxesFull = bboxes(pIidx,:);
      
      if ~update  
        obj.init('initTrnLog',false);
        % record normalized training shapes for propagation initialization
        pGTN = shapeGt('projectPose',model,pGT,bboxes);
        obj.pGTNTrn = pGTN;
      end
      
      loss = mean(shapeGt('dist',model,pCur,pGTFull));
      if verbose
        fprintf('  t=%i/%i       loss=%f     \n',t0-1,T,loss);
      end
      tStart = clock;
      
      paramFtr = obj.prmFtr;
      ftrRadiusOrig = paramFtr.radius; % for t-dependent ftr radius
      paramReg = obj.prmReg;
      
      maxFernAbsDeltaPct = nan(1,T);
      for t=t0:T
        if paramReg.USE_AL_CORRECTION
          pCurN_al = shapeGt('projectPose',model,pCur,bboxesFull);
          pGtN_al = shapeGt('projectPose',model,pGTFull,bboxesFull);
          assert(isequal(size(pCurN_al),size(pGtN_al)));
          pDiffN_al = Shape.rotInvariantDiff(pCurN_al,pGtN_al,1,3); % XXXAL HARDCODED HEAD/TAIL
          pTar = pDiffN_al;
        else
          pTar = shapeGt('inverse',model,pCur,bboxesFull); % pCur: absolute. pTar: normalized
          pTar = shapeGt('compose',model,pTar,pGTFull,bboxesFull); % pTar: normalized
        end
        
        if numel(ftrRadiusOrig)>1
          paramFtr.radius = ftrRadiusOrig(min(t,numel(ftrRadiusOrig)));
        end
        
        % Generate feature specs
        if ~update
          switch paramFtr.type
            case {'kborig_hack'}
              fspec = shapeGt('ftrsGenKBOrig',model,paramFtr);
            case {'1lm' '2lm' '2lmdiff'}
              fspec = shapeGt('ftrsGenDup2',model,paramFtr);
          end
          obj.ftrSpecs{t} = fspec;
        end
        
        % compute features for current training shapes
        [X,iFtrsComp] = obj.computeFeatures(t,I,bboxes,pCur,pIidx,update);
        
        % Regress
        paramReg.ftrPrm = paramFtr;
        paramReg.prm.useFern3 = true;
        fernOutput0 = squeeze(obj.fernOutput(t,:,:,:));
        if ~update
          [regInfo,pDel] = regTrain(X,pTar,paramReg); 
          assert(iscell(regInfo) && numel(regInfo)==obj.nMinor);
          for u=1:obj.nMinor
            ri = regInfo{u};          
            obj.ftrsUse(t,u,:,:) = ri.fids';          
            obj.fernN(t,u) = ri.N;
            obj.fernMu(t,u,:) = ri.yMu;
            obj.fernThresh(t,u,:) = ri.thrs;
            obj.fernSums(t,u,:,:) = ri.fernSum;
            obj.fernCounts(t,u,:,:) = ri.fernCount;
            obj.fernOutput(t,u,:,:) = ri.ysFern;
            obj.fernTS(t,u) = now();
          end
        else
          % update: fernN, fernCounts, fernSums, fernOutput, fernTS
          % calc: pDel          
          
          pDel = obj.fernUpdate(t,X,iFtrsComp,pTar,paramReg);
        end
        fernOutput1 = squeeze(obj.fernOutput(t,:,:,:));
        maxFernAbsDeltaPct(t) = obj.computeMaxFernAbsDelta(fernOutput0,fernOutput1);
                  
        % Apply pDel
        if paramReg.USE_AL_CORRECTION
          pCur = Shape.applyRIDiff(pCurN_al,pDel,1,3); %XXXAL HARDCODED HEAD/TAIL
          pCur = shapeGt('reprojectPose',model,pCur,bboxesFull);
        else
          pCur = shapeGt('compose',model,pDel,pCur,bboxesFull);
          pCur = shapeGt('reprojectPose',model,pCur,bboxesFull);
        end
        pAll(:,:,t+1) = pCur;
        
        errPerEx = shapeGt('dist',model,pCur,pGTFull);
        loss = mean(errPerEx);        
        if verbose
          msg = tStatus(tStart,t,T);
          fprintf(['  t=%i/%i       loss=%f     ' msg],t,T,loss);
        end        
      end
      
      if update
        act = 'retrain';
      else
        act = 'train';
      end      
      obj.trnLog(end+1,1).action = act;
      obj.trnLog(end).ts = now();
      obj.trnLog(end).nShape = Q;
      obj.trnLog(end).maxFernAbsDeltaPct = maxFernAbsDeltaPct;
    end
    
    function trnLogInit(obj)
      obj.trnLog = struct(...
        'action',cell(0,1),... % 'train' or 'retrain'
        'ts',[],... % timestamp
        'nShape',[],... % number of shapes (after any augmentation) trained/added
        'maxFernAbsDeltaPct',[]... % 1xnMjr; maximum delta (L2 norm, pct of mu) in obj.fernOutput(iMjr,:,:,:) over all
        );                         % minor iters, fern bins
    end
        
    function iTL = trnLogMostRecentTrain(obj)
      tl = obj.trnLog;
      act = {tl.action};
      iTL = find(strcmp(act,'train'),1,'last');
    end
    
    function trnLogPrintSinceLastTrain(obj)
      % Pretty-print log from last (full) train onwards

      iTL = obj.trnLogMostRecentTrain();
      if isempty(iTL)
        fprintf('No training has occurred.\n');
      else
        tl = obj.trnLog;
        for i=iTL:numel(tl)
          tlcurr = tl(i);
          fprintf('%s: %s with nShape=%d\n',...
            datestr(tlcurr.ts,'mmm-dd HH:MM:SS'),...
            tlcurr.action,tlcurr.nShape);
        end
      end      
    end
       
    function p_t = propagate(obj,I,bboxes,p0,pIidx,varargin) % obj const
      % Propagate shapes through regressor cascade.
      %
      % I: [N] Cell array of images
      % bboxes: [Nx2*d]
      % p0: [QxD] initial shapes, absolute coords, eg Q=N*augFactor
      % pIidx: [Q] indices into I for rows of p0
      %
      % p_t: [QxDx(T+1)] All shapes over time. p_t(:,:,1)=p0; p_t(:,:,end)
      % is shape after T'th major iteration.
      %
      
      [t0,hWB] = myparse(varargin,...
        't0',1,... % initial/starting major iteration
        'hWaitBar',[]);
      tfWB = ~isempty(hWB);
  
      NI = numel(I);
      assert(isequal(size(bboxes),[NI 2*obj.mdld]));
      [Q,D] = size(p0);
      assert(numel(pIidx)==Q && all(ismember(pIidx,1:NI)));
      assert(D==obj.mdlD);
  
      model = obj.prmModel;
      ftrMetaType = obj.prmFtr.metatype;
      bbs = bboxes(pIidx,:);
      T = obj.nMajor;
      p_t = zeros(Q,D,T+1); % shapes over all initial conds/iterations, absolute coords
      p_t(:,:,1) = p0;
      p = p0; % current/working shape, absolute coords
                   
      if tfWB
        waitbar(0,hWB,'Applying cascaded regressor');
      end
      for t = t0:T
        if tfWB
          waitbar(t/T,hWB);
        else
          fprintf(1,'Applying cascaded regressor: %d/%d\n',t,T);
        end
              
        [X,iFtrsComp] = obj.computeFeatures(t,I,bboxes,p,pIidx,true);
        assert(numel(iFtrsComp)==size(X,2));

        % Compute shape correction (normalized units) by summing over
        % microregressors
        pDel = zeros(Q,D);
        for u=1:obj.nMinor
          x = obj.computeMetaFeature(X,iFtrsComp,t,u,ftrMetaType);
          thrs = squeeze(obj.fernThresh(t,u,:));
          inds = fernsInds(x,uint32(1:obj.M),thrs(:)'); 
          yFern = squeeze(obj.fernOutput(t,u,inds,:));
          assert(ndims(yFern)==2); %#ok<ISMAT>
          pDel = pDel + yFern; % normalized units
        end
        
        if obj.prmReg.USE_AL_CORRECTION
          p1 = shapeGt('projectPose',model,p,bbs); % p1 is normalized        
          p = Shape.applyRIDiff(p1,pDel,1,3); % XXXAL HARDCODED HEAD/TAIL
        else
          p = shapeGt('compose',model,pDel,p,bbs); % p (output) is normalized
        end
        p = shapeGt('reprojectPose',model,p,bbs); % back to absolute coords
        p_t(:,:,t+1) = p;
      end
    end
    
    function p_t = propagateRandInit(obj,I,bboxes,prmTestInit,varargin) % obj const
      % 
      
      model = obj.prmModel;
      n = numel(I);
      assert(isequal(size(bboxes),[n 2*model.d]))
      
      nRep = prmTestInit.Nrep;
      pGTTrnNMu = nanmean(obj.pGTNTrn,1);
      p0 = shapeGt('initTest',[],bboxes,model,[],...
        repmat(pGTTrnNMu,n,1),nRep,prmTestInit.augrotate); % [nxDxnRep]
      p0 = permute(p0,[1 3 2]); % [nxnRepxD]
      p0 = reshape(p0,[n*nRep model.D]);
      pIidx = repmat(1:n,[1 nRep])';
      
      p_t = obj.propagate(I,bboxes,p0,pIidx,varargin{:});      
    end
        
    function yPred = fernUpdate(obj,t,X,iFtrsComp,yTar,prmReg)
      % Incremental update of fern structures
      %
      % t: major iter
      % X: [QxnUsed], computed features
      % iFtrsComp: [nUsed], feature indices labeling cols of X
      % yTar: [QxD] target shapes
      % prmReg: 
      %
      % yPred: [QxD], fern prediction on X (summed/boosted over minor iters)
      
      [Q,nU] = size(X);
      assert(numel(iFtrsComp)==nU);
      D = obj.mdlD;
      assert(isequal(size(yTar),[Q D]));
      
      ftrMetaType = obj.prmFtr.metatype;
      MM = obj.M;
      fids = uint32(1:MM);
      ySum = zeros(Q,D); % running accumulation of approx to pTar
      for u=1:obj.nMinor
        yTarMnr = yTar - ySum;
        x = obj.computeMetaFeature(X,iFtrsComp,t,u,ftrMetaType);
        assert(isequal(size(x),[Q MM]));
        thrs = squeeze(obj.fernThresh(t,u,:));
        
        yMuOrig = reshape(obj.fernMu(t,u,:),[1 D]);
        dY = bsxfun(@minus,yTarMnr,yMuOrig);
        [inds,dyFernSum,~,dyFernCnt] = Ferns.fernsInds3(x,fids,thrs,dY);
        indsTMP = fernsInds(x,fids,thrs); % dumb check
        assert(isequal(inds,indsTMP));
               
        obj.fernN(t,u) = obj.fernN(t,u) + Q;
        obj.fernCounts(t,u,:,:) = squeeze(obj.fernCounts(t,u,:,:)) + dyFernCnt;
        obj.fernSums(t,u,:,:) = squeeze(obj.fernSums(t,u,:,:)) + dyFernSum;
        
        counts = squeeze(obj.fernCounts(t,u,:,:));
        sums = squeeze(obj.fernSums(t,u,:,:));
        ysFernCntUse = max(counts+prmReg.prm.reg*obj.fernN(t,u),eps);
        ysFern = bsxfun(@plus,sums./ysFernCntUse,yMuOrig);
        
        obj.fernOutput(t,u,:,:) = ysFern;
        
        yPredMnr = ysFern(inds,:);
        ySum = ySum + yPredMnr;
        
        obj.fernTS(t,u) = now();
      end
      
      yPred = ySum;

      
      % See train() for parameter descriptions. The difference here is that
      % I, bboxes, pGT etc represent new/additional images+gtShapes to
      % integrate into the cascade.
      %
      % In an incremental update:
      % - The set of available features for each major iter are re-used;
      % - The selected subset of features used in each minor iter are re-used;
      % - fern thresholds are not touched;
      % -.fernN will be updated
      % - .fernCounts will be augmented with ~<Q counts for each coord, for
      %   each (mjr,mnr) iteration;
      % - .fernOutput will be updated with adding in a contribution for Q
      %   new datapoints (weighted against the N_existing datapoints)
      % - The new shapes are propagated through the cascade using the 
      %   updated fernCounts/Output etc. Note however that the previous/
      %   existing datapoints are NOT repropagated using these updated fern
      %   props. This is a fundamental deviation from a full retraining.
      
    end
    
    function x = computeMetaFeature(obj,X,iFtrsX,t,u,metatype)
      % Helper function to compute meta-features
      %
      % X: [QxZ] computed features
      % iFtrsX: [Z] feature indices labeling cols of X (indices into ftrsSpecs{t})
      % t: major iter
      % u: minor iter
      % metatype: either 'single' or 'diff'
      %
      % x: [QxM] meta-features
      
      iFtrsUsed = squeeze(obj.ftrsUse(t,u,:,:)); % [MxnUse]
      nUse = size(iFtrsUsed,2);
      switch metatype
        case 'single'
          assert(nUse==1);
          [~,loc] = ismember(iFtrsUsed,iFtrsX);
          x = X(:,loc);
        case 'diff'
          assert(nUse==2);
          [~,loc1] = ismember(iFtrsUsed(:,1),iFtrsX);
          [~,loc2] = ismember(iFtrsUsed(:,2),iFtrsX);
          x = X(:,loc1)-X(:,loc2);
      end      
      
    end
    
    function maxFernAbsDeltaPct = computeMaxFernAbsDelta(obj,fernOutput0,fernOutput1)
      % fernOutput0/1: [nMnr x 2^M x D]
      %
      % maxFernAbsDeltaPct: scalar. Maximum of L2Delta./L2mu, over
      % all bins, over all minor iters
      
      assert(isequal(obj.nMinor,size(fernOutput0,1),size(fernOutput1,1)));
      
      maxFernAbsDeltaPct = nan(obj.nMinor,1);
      for iMnr = 1:obj.nMinor
        del = squeeze(fernOutput1(iMnr,:,:)-fernOutput0(iMnr,:,:)); % [2^M x D]
        del = sqrt(sum(del.^2,2)); % [2^Mx1], L2 deviation for each fern bin (for this minor iter)
        mu = squeeze(fernOutput1(iMnr,:,:)+fernOutput0(iMnr,:,:))/2;
        mu = sqrt(sum(mu.^2,2)); % [2^Mx1], L2 of fern output vec for each fern bin (etc)
        
        maxFernAbsDeltaPct(iMnr) = max(del./mu);
      end
      
      maxFernAbsDeltaPct = max(maxFernAbsDeltaPct);
      
    end
  end
    
end
  
function msg = tStatus(tStart,t,T)
elptime = etime(clock,tStart);
fracDone = max( t/T, .00001 );
esttime = elptime/fracDone - elptime;
if( elptime/fracDone < 600 )
  elptimeS  = num2str(elptime,'%.1f');
  esttimeS  = num2str(esttime,'%.1f');
  timetypeS = 's';
else
  elptimeS  = num2str(elptime/60,'%.1f');
  esttimeS  = num2str(esttime/60,'%.1f');
  timetypeS = 'm';
end
msg = ['[elapsed=' elptimeS timetypeS ...
  ' / remaining~=' esttimeS timetypeS ']\n' ];
end