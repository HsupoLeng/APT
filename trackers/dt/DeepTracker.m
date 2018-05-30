classdef DeepTracker < LabelTracker
  
  properties
    algorithmName = 'poseTF';
  end
  properties (Constant,Hidden)
    SAVEPROPS = {'sPrm' 'trnName' 'movIdx2trkfile' 'hideViz'};    
  end
  properties
    sPrm % new-style DT params
    
    dryRunOnly % transient, scalar logical. If true, stripped lbl, cmds 
      % are generated for DL, but actual DL train/track are not spawned
    
    %% train
    
    % - The trained model lives in the fileSys in <cacheDir>/<proj>view%d/trnName.
    % - Right now you can only have one train running at a time.
    
    % char, currently autogenerated.
    % - When you retrain, you make a new trnName, every time.
    % - As far as DeepTracker.m is concerned, the only output/artifact 
    % generated by training is this identifier. It specifies a filesystem 
    % location where a trained model is expected to live.
    % FUTURE TODO: what happens when user alters cacheDir?
    trnName 
    
    bgTrnMonitorClient % BGClient obj
    bgTrnMonitorWorkerObj; % scalar "detached" object that is deep-copied onto 
      % workers. Note, this is not the BGWorker obj itself
    bgTrnMonitorResultsMonitor % object with resultsreceived() method 
    
    %% track

    % - Right now you can only have one track running at a time.
    
    bgTrkMonitorClient
    bgTrkMonitorWorkerObj
    %bgTrkMonitorResultsMonitor 
    
    % trackres: tracking results DB is in filesys
    movIdx2trkfile % map from MovieIndex.id to [1xnview] cellstrs of trkfile fullpaths
  end
  properties (Dependent)
    bgTrnReady % If true, asyncPrepare() has been called and asyncStartBGWorker() can be called
  end

  properties
    % track curr res -- in-mem tracking results for current mov    
    trkP   % [npt x 2 x nfrm x ntgt] tracking results for current mov
    trkPTS % [npt x nfrm x ntgt] timestamp for trkP*
%     trkPMD % [NTst <ncols>] table. cols: .mov, .frm, .iTgt
%            % .mov has class movieIndex           
    % viz
    hXYPrdRed; % [npts] plot handles for 'reduced' tracking results, current frame and target
    hXYPrdRedOther; % [npts] plot handles for 'reduced' tracking results, current frame, non-current-target
    xyVizPlotArgs; % cell array of args for regular tracking viz    
    xyVizPlotArgsNonTarget; % " for non current target viz
  end
  properties (Dependent)
    nPts % number of label points     
    nview 
    %hasTrained
  end
  
  events
    % Thrown when new tracking results are loaded for the current lObj
    % movie
    newTrackingResults 
  end
  
  methods
    function v = get.nPts(obj)
      v = obj.lObj.nLabelPoints;
    end
    function v = get.nview(obj)
      v = obj.lObj.nview;
    end
    function v = get.bgTrnReady(obj)
      v = ~isempty(obj.bgTrnMonitorClient);
    end
  end
  
  methods
    function obj = DeepTracker(lObj)
      obj@LabelTracker(lObj);
    end    
    function initHook(obj)
      obj.trnResInit();
      obj.bgTrnReset();
      obj.bgTrkReset();
      obj.trackResInit();
      obj.trackCurrResInit();
      obj.vizInit();
    end
  end
  
  %% Params
  methods
    function setParams(obj,sPrm)
      % XXX TODO: invalidating/clearing state
      obj.sPrm = sPrm;
    end
    function sPrm = getParams(obj)
      sPrm = obj.sPrm;
    end
    function s = getSaveToken(obj)
      s = struct();
      props = obj.SAVEPROPS;
      for p=props(:)',p=p{1}; %#ok<FXSET>
        s.(p) = obj.(p);
      end      
    end
    function loadSaveToken(obj,s)
      obj.initHook(); % maybe handled upstream
      flds = fieldnames(s);
      flds = setdiff(flds,'hideViz');
      %obj.isInit = true;
%       try
      for f=flds(:)',f=f{1}; %#ok<FXSET>
        obj.(f) = s.(f);
      end
%       catch ME
        %obj.isInit = false;
%         ME.rethrow();
%       end
      %obj.isInit = false;      
      
      obj.dryRunOnly = false;
      
      obj.setHideViz(s.hideViz);
      obj.trackCurrResUpdate();
      obj.newLabelerFrame();
    end
  end
  
  
  %% Train
  methods
    
    function train(obj)
      error('Incremental training is currently unsupported by PoseTF.');
    end
    
    % Training timeline
    %
    % - Call to retrain. this creates a new jobname every time.
    % - stripped lbl written to <cacheDir>/<trnID>.lbl
    % - bg trn monitor started
    % - training spawned
    % - as log/intermediate results are written, loss viz in plot.
    % - you can start tracking at any time with the latest model by calling
    % track().
    % - FUTURE TODO you can't forcibly stop training for now.
    % - FUTURE TODO you can't choose to use a trained model before the last/final
    % - FUTURE TODO clean up old/unwanted trained models.
    % one if say it looked less overtrained or better.
    % - trained models will sit on disk; stripped lbl at 
    % <cache>/<trnName>.lbl, and models at <cache>/.../<trnName>
    
    function trnResInit(obj)
      obj.trnName = '';
      obj.bgTrnReset();
    end
    
    function retrain(obj,varargin)

      if isempty(obj.sPrm)
        error('No tracking parameters have been set.');
      end
      cacheDir = obj.sPrm.CacheDir;
      if isempty(cacheDir)
        error('No cache directory has been set.');
      end
      
      lblObj = obj.lObj;
      projname = lblObj.projname;
      if isempty(projname)
        error('Please give your project a name. The project name will be used to identify your trained models on disk.');
      end
      trnID = datestr(now,'yyyymmddTHHMMSS');
      

      if ~isempty(obj.trnName)
        trnNameOld = fullfile(cacheDir,'...',obj.trnName);
        trnNameNew = fullfile(cacheDir,'...',trnID);
        warningNoTrace('New trained model will be created at %s. Previous trained model at %s will not be deleted.',...
          trnNameNew,trnNameOld);
      end
      obj.trnName = trnID;
      
      % Write stripped lblfile to cacheDir
      s = lblObj.trackCreateDeepTrackerStrippedLbl(); %#ok<NASGU>
      dlLblFile = fullfile(cacheDir,[trnID '.lbl']);      
      trnLogFile = fullfile(cacheDir,[trnID '.log']);
      save(dlLblFile,'-mat','-struct','s');
      fprintf('Saved stripped lbl file: %s\n',dlLblFile);

      cmd = DeepTracker.trainCodeGenBsubSing(trnID,dlLblFile,{},...
        'outfile',trnLogFile);
      
      if obj.dryRunOnly
        fprintf(1,'Dry run, not training: %s\n',cmd);
      else
        % call train monitor
        obj.bgTrnPrepareMonitor(dlLblFile,trnID);
        obj.bgTrnStart();

        % spawn training
        fprintf(1,'%s\n',cmd);
        system(cmd);
      end
    end
    
    function bgTrnReset(obj)
      % Reset BG Train Monitor state
      %
      % - TODO Note, when you change eg params, u need to call this. etc etc.
      % Any mutation that alters PP, train/track on the BG worker...

      if ~isempty(obj.bgTrnMonitorClient)
        delete(obj.bgTrnMonitorClient);
      end
      obj.bgTrnMonitorClient = [];
      
      if ~isempty(obj.bgTrnMonitorWorkerObj)
        delete(obj.bgTrnMonitorWorkerObj)
      end
      obj.bgTrnMonitorWorkerObj = [];
      
      if ~isempty(obj.bgTrnMonitorResultsMonitor)
        delete(obj.bgTrnMonitorResultsMonitor);
      end
      obj.bgTrnMonitorResultsMonitor = [];
    end
    
    function bgTrnPrepareMonitor(obj,dlLblFile,jobID)
      obj.bgTrnReset();

      objMon = DeepTrackerTrainingMonitor(obj.lObj.nview);
      cbkResult = @obj.bgTrnResultsReceived;
      workerObj = DeepTrackerTrainingWorkerObj(dlLblFile,jobID);
      bgc = BGClient;
      fprintf(1,'Configuring background worker...\n');
      bgc.configure(cbkResult,workerObj,'compute');
      obj.bgTrnMonitorClient = bgc;
      obj.bgTrnMonitorWorkerObj = workerObj;
      obj.bgTrnMonitorResultsMonitor = objMon;
    end
    
    function bgTrnStart(obj)
      assert(obj.bgTrnReady);
      obj.bgTrnMonitorClient.startWorker('workerContinuous',true,...
        'continuousCallInterval',10);
    end
    
    function bgTrnResultsReceived(obj,sRes)
      obj.bgTrnMonitorResultsMonitor.resultsReceived(sRes);
      
      % XXX TODO call bgTrnStop when done. 
    end
    
    function bgTrnStop(obj)
      obj.bgTrnMonitorClient.stopWorker();
    end       
    
  end
  
  %% Track
  
  methods
    
    % Tracking timeline
    % - Call to track. We are talking a single movie right now.
    % - .trnName must be set. The current backend behavior is the most 
    % recent model in <cache>/.../trnName will be used
    % - BG track monitor started. This polls the filesys for the output
    % file.
    % - Spawn track shell call.
    % - When tracking is done for a view, movIdx2trkfile is updated.
    % - When tracking is done for all views, we stop the bgMonitor and we
    % are done.
    
    function track(obj,tblMFT,varargin)
      % Apply trained tracker to the specified frames.
      % 
      % tblMFT: MFTable with cols MFTable.FLDSID
      
      if isempty(tblMFT)
        warningNoTrace('Nothing to track.');
        return;
      end
        
      % figure out what to track
      tblMFT = MFTable.sortCanonical(tblMFT);
      mIdx = unique(tblMFT.mov);
      if ~isscalar(mIdx)
        error('DeepTracker: tracking only single movies is currently supported.');
      end
      tMFTConc = obj.lObj.mftTableConcretizeMov(tblMFT);
      
      tftrx = obj.lObj.hasTrx;
      if tftrx
        trxids = unique(tblMFT.iTgt);
        f0 = min(tblMFT.frm);
        f1 = max(tblMFT.frm);
        trxfile = unique(tMFTConc.trxFile);
        assert(isscalar(trxfile));
        trxfile = trxfile{1};
        % More complex version of warning below would apply
      else
        f0 = tblMFT.frm(1);
        f1 = tblMFT.frm(end);
        if ~isequal((f0:f1)',tblMFT.frm)
          warningNoTrace('Tracking additional frames to form continuous sequence.');
        end
      end
      
      % check trained tracker
      if isempty(obj.trnName)
        error('No trained tracker found.');
      end
      trnID = obj.trnName;
      cacheDir = obj.sPrm.CacheDir;
      dlLblFile = fullfile(cacheDir,[trnID '.lbl']);
      if exist(dlLblFile,'file')==0
        error('Cannot find training file: %s\n',dlLblFile);
      end
      
      nView = obj.lObj.nview;
      assert(nView==1,'TODO: Currently only single-view projects are supported.');
      movs = tMFTConc.mov;
      assert(size(movs,2)==nView);
      movs = movs(1,:);
      nowstr = datestr(now,'yyyymmddTHHMMSS');
      for ivw=1:nView
        mov = movs{ivw};
        [movP,movF] = fileparts(mov);
        trkfile = fullfile(movP,[movF '_' nowstr '.trk']);
        outfile = fullfile(movP,[movF '_' nowstr '.log']);
        fprintf('View %d: trkfile will be written to %s\n',ivw,trkfile);        
        
        if tftrx
          baseargs = {'trxtrk' trxfile 'trxids' trxids};           
        else
          baseargs = {};
        end
        bsubargs = {'outfile',outfile};
        codestr = DeepTracker.trackCodeGenBsubSing(trnID,dlLblFile,mov,...
          trkfile,f0,f1,'baseargs',baseargs,'bsubargs',bsubargs);
        
        if obj.dryRunOnly
          fprintf('Dry run, not tracking: %s\n',codestr);
        else
          obj.bgTrkPrepareMonitor(mIdx,ivw,mov,trkfile);
          obj.bgTrkStart();

          fprintf('%s\n',codestr);
          system(codestr);
        end
        
        % what happens on err?  
      end      
    end
    
    function bgTrkReset(obj)
      if ~isempty(obj.bgTrkMonitorClient)
        delete(obj.bgTrkMonitorClient);
      end
      obj.bgTrkMonitorClient = [];
      if ~isempty(obj.bgTrkMonitorWorkerObj)
        delete(obj.bgTrkMonitorWorkerObj)
      end
      obj.bgTrkMonitorWorkerObj = [];      
    end
    
    function bgTrkPrepareMonitor(obj,mIdx,iview,movfile,outfile)
      obj.bgTrkReset();

      cbkResult = @obj.bgTrkResultsReceived;
      workerObj = DeepTrackerTrackingWorkerObj(mIdx,iview,movfile,outfile);
      bgc = BGClient;
      fprintf(1,'Configuring tracking background worker...\n');
      bgc.configure(cbkResult,workerObj,'compute');
      obj.bgTrkMonitorClient = bgc;
      obj.bgTrkMonitorWorkerObj = workerObj;
    end
    
    function bgTrkStart(obj)
      obj.bgTrkMonitorClient.startWorker('workerContinuous',true,...
        'continuousCallInterval',10);
    end
    
    function bgTrkResultsReceived(obj,sRes)
      res = sRes.result;
      if res.tfcomplete
        fprintf(1,'Tracking output file %s detected.\n',res.trkfile);
        obj.bgTrkStop();
        movsFull = obj.lObj.getMovieFilesAllFullMovIdx(res.mIdx);
        mov = movsFull{res.iview};
        if strcmp(mov,res.movfile)
          obj.trackResNewTrkfile(res.mIdx,res.iview,res.trkfile);
          if res.mIdx==obj.lObj.currMovIdx
            obj.trackCurrResUpdate();
            obj.newLabelerFrame();
            fprintf('Tracking complete at %s.\n',datestr(now));
          end          
        else
          warningNoTrace('Tracking complete, but movieset %d, view%d, mov %s does not match current project.',...
            int32(res.mIdx),res.iview,res.movfile);
          % conservative, take no action for now
        end
      end
    end
    
    function bgTrkStop(obj)
      obj.bgTrkMonitorClient.stopWorker();
    end       
    
  end
  methods (Static) % codegen
    function codestr = codeGenSingGeneral(basecmd,varargin)
      % Take a base command and run it in a sing img
      DFLTBINDPATH = {
        '/groups/branson/bransonlab'
        '/groups/branson/home'
        '/nrs/branson'
        '/scratch'};      
      [bindpath,singimg] = myparse(varargin,...
        'bindpath',DFLTBINDPATH,...
        'singimg','/misc/local/singularity/branson_v2.simg');
      
      Bflags = [repmat({'-B'},1,numel(bindpath)); bindpath(:)'];
      Bflagsstr = sprintf('%s ',Bflags{:});
      codestr = sprintf('singularity exec --nv %s %s bash -c ". /opt/venv/bin/activate && %s"',...
        Bflagsstr,singimg,basecmd);
    end
    function codestr = codeGenBsubGeneral(basecmd,varargin)
      [nslots,gpuqueue,outfile] = myparse(varargin,...
        'nslots',1,...
        'gpuqueue','gpu_any',...
        'outfile','/dev/null');
      codestr = sprintf('bsub -n %d -gpu "num=1" -q %s -o %s %s',...
        nslots,gpuqueue,outfile,basecmd);      
    end
    function codestr = trainCodeGen(trnID,dllbl)
      aptintrf = fullfile(APT.getpathdl,'APT_interface.py');
      codestr = sprintf('python %s -name %s %s train',aptintrf,trnID,dllbl);
    end
    function codestr = trainCodeGenSing(trnID,dllbl,varargin)
      basecmd = DeepTracker.trainCodeGen(trnID,dllbl);
      codestr = DeepTracker.codeGenSingGeneral(basecmd,varargin{:});
    end
    function codestr = trainCodeGenBsubSing(trnID,dllbl,singargs,varargin)
      basecmd = DeepTracker.trainCodeGenSing(trnID,dllbl,singargs{:});
      codestr = DeepTracker.codeGenBsubGeneral(basecmd,varargin{:});
    end    
    function codestr = trackCodeGenBase(trnID,dllbl,movtrk,outtrk,frm0,frm1,varargin)
      [trxtrk,trxids] = myparse(varargin,...
        'trxtrk','',... % (opt) trkfile for movtrk to be tracked 
        'trxids',[]); % (opt) 1-based index into trx structure in trxtrk. empty=>all trx
      
      tftrx = ~isempty(trxtrk);
      tftrxids = ~isempty(trxids);
      
      aptintrf = fullfile(APT.getpathdl,'APT_interface.py');
      
      if tftrx
        if tftrxids
          trxids = num2cell(trxids-1); % convert to 0-based for py
          trxidstr = sprintf('%d ',trxids{:});
          trxidstr = trxidstr(1:end-1);
          codestr = sprintf('python %s -name %s %s track -mov %s -trx %s -out %s -start_frame %d -end_frame %d -trx_ids %s',...
            aptintrf,trnID,dllbl,movtrk,trxtrk,outtrk,frm0,frm1,trxidstr);          
        else
          codestr = sprintf('python %s -name %s %s track -mov %s -trx %s -out %s -start_frame %d -end_frame %d',...
            aptintrf,trnID,dllbl,movtrk,trxtrk,outtrk,frm0,frm1);
        end
      else
        codestr = sprintf('python %s -name %s %s track -mov %s -out %s -start_frame %d -end_frame %d',...
          aptintrf,trnID,dllbl,movtrk,outtrk,frm0,frm1);
      end
    end
    function codestr = trackCodeGenVenv(trnID,dllbl,movtrk,outtrk,frm0,frm1,varargin)
      % TODO: views
      
      [baseargs,venvHost,venv,cudaVisDevice,logFile] = myparse(varargin,...
        'baseargs',{},... % p-v cell for trackCodeGenBase
        'venvHost','10.103.20.155',... % host to run DL verman-ws1
        'venv','/groups/branson/bransonlab/mayank/venv',... 
        'cudaVisDevice',[],... % if supplied, export CUDA_VISIBLE_DEVICES to this
        'logFile','/dev/null'...
      ); 
      
      basecode = DeepTracker.trackCodeGenBase(trnID,dllbl,movtrk,outtrk,...
        frm0,frm1,baseargs{:});
      if ~isempty(cudaVisDevice)
        cudaDeviceStr = ...
          sprintf('export CUDA_DEVICE_ORDER=PCI_BUS_ID; export CUDA_VISIBLE_DEVICES=%d; ',...
          cudaVisDevice);
      else
        cudaDeviceStr = '';
      end
        
      codestrremote = sprintf('cd %s; source bin/activate; %s%s',venv,...
        cudaDeviceStr,basecode);
      codestr = sprintf('ssh %s "%s" </dev/null  >%s 2>&1 &"',...
        venvHost,codestrremote,logFile);      
    end
    function codestr = trackCodeGenSing(trnID,dllbl,movtrk,outtrk,frm0,...
        frm1,varargin)
      [baseargs,singargs] = myparse(varargin,...
        'baseargs',{},...
        'singargs',{});
      basecmd = DeepTracker.trackCodeGenBase(trnID,dllbl,movtrk,outtrk,...
        frm0,frm1,baseargs{:});
      codestr = DeepTracker.codeGenSingGeneral(basecmd,singargs{:});
    end
    function codestr = trackCodeGenBsubSing(trnID,dllbl,movtrk,outtrk,...
        frm0,frm1,varargin)
      [baseargs,singargs,bsubargs] = myparse(varargin,...
        'baseargs',{},...
        'singargs',{},...
        'bsubargs',{});
      basecmd = DeepTracker.trackCodeGenSing(trnID,dllbl,movtrk,outtrk,...
        frm0,frm1,'baseargs',baseargs,'singargs',singargs);
      codestr = DeepTracker.codeGenBsubGeneral(basecmd,bsubargs{:});
    end
  end
  
  %% TrackRes = Tracking DB. all known tracking results on disk.  
  methods
    function trackResInit(obj)
      m = containers.Map('keytype','int32','valuetype','any');
      obj.movIdx2trkfile = m;
    end
    function trackResNewTrkfile(obj,mIdx,iview,trkfile)
      m = obj.movIdx2trkfile;
      assert(isscalar(mIdx));
      assert(ischar(trkfile));
      id = mIdx.id32();
      if m.isKey(id)
        v = m(id);
      else
        v = cell(1,obj.lObj.nview);
      end
      v{iview} = trkfile;
      m(id) = v; %#ok<NASGU>
    end
    function tpos = getTrackingResultsCurrMovie(obj)
      tpos = obj.trkP;
    end
    function [trkfiles,tfHasRes] = getTrackingResults(obj,mIdx)
      % Get tracking results for MovieIndices mIdx
      %
      % mIdx: [nMov] vector of MovieIndices
      %
      % trkfiles: [nMovxnView] vector of TrkFile objects
      % tfHasRes: [nMov] logical. If true, corresponding movie(set) has 
      % tracking nontrivial (nonempty) tracking results
      %
      % DeepTracker uses the filesys as the tracking result DB. This loads 
      % from known/expected trkfiles.
      
      assert(isa(mIdx,'MovieIndex'));
      nMov = numel(mIdx);
      m = obj.movIdx2trkfile;
      nView = obj.nview;
      for i = nMov:-1:1
        id = mIdx(i).id32;
        if m.isKey(id)
          v = m(id);
        else
          v = cell(1,nView);
        end
        for ivw=nView:-1:1
          tfilefull = v{ivw};
          if ~isempty(tfilefull)
            try
              trkfiles(i,ivw) = load(tfilefull,'-mat'); % TrkFile.load erroring, poseTF trkfiles contain extra stuff
              tfHasRes(i,ivw) = true;
            catch ME
              warningNoTrace('Failed to load trkfile: ''%s''. Error: %s',...
                tfilefull,ME.message);
              trkfiles(i,ivw) = TrkFile;
              tfHasRes(i,ivw) = false;
            end
          else          
            trkfiles(i,ivw) = TrkFile;
            tfHasRes(i,ivw) = false;
          end
        end
      end
    end
    function [tblTrkRes,pTrkiPt] = getAllTrackResTable(obj) % obj const
      % Get all current tracking results in a table
      %
      % tblTrkRes: [NTrk x ncol] table of tracking results
      %            .pTrk, like obj.trkP; ABSOLUTE coords
      % pTrkiPt: [npttrk] indices into 1:obj.npts, tracked points. 
      %          size(tblTrkRes.pTrk,2)==npttrk*d

      if obj.lObj.nview>1
        error('Currently unsupported for multiview projects.');
      end
      
      m = obj.movIdx2trkfile;
      mIdxs = m.keys;
      mIdxs = cell2mat(mIdxs(:));
      [trk,tfhasres] = obj.getTrackingResults(mIdxs);

      tblTrkRes = [];
      pTrkiPt = -1;
      for i=1:numel(mIdxs)
        if tfhasres(i)
          if isequal(pTrkiPt,-1)
            pTrkiPt = trk(i).pTrkiPt;
          end
          if ~isequal(pTrkiPt,trk(i).pTrkiPt)
            error('Trkfiles differ in tracked points .pTrkiPt.');
          end
          tbl = trk(i).tableform;
          tblTrkRes = [tblTrkRes;tbl]; %#ok<AGROW>
        end         
      end
    end
    function clearTrackingResults(obj)
      % FUTURE TODO: For now we do not actually delete the previous trkfiles.
      obj.trackResInit();
      obj.trackCurrResUpdate();
      obj.newLabelerFrame();
    end
  end
  
  %% TrackCurrRes = tracked state for current movie. Loaded into .trkP*
  methods
    function trackCurrResInit(obj)
      obj.trkP = [];
      obj.trkPTS = zeros(0,1);
    end
    function trackCurrResUpdate(obj)
      % update trackCurrRes (.trkP*) from trackRes (tracking DB)
      mIdx = obj.lObj.currMovIdx;
      if isempty(mIdx)
        % proj load etc
        return;
      end
      [trks,tfHasRes] = obj.getTrackingResults(mIdx);
      if tfHasRes
        obj.trackCurrResLoadFromTrks(trks);
      else
        obj.trackCurrResInit();
      end
      notify(obj,'newTrackingResults');
    end
    function trackCurrResLoadFromTrks(obj,trks)
      % trks: [nview] struct, TrkFile contents
      
      assert(numel(trks)==obj.nview);
      
      lObj = obj.lObj;
      ipt2view = lObj.labeledposIPt2View;
      pTrk = nan(obj.nPts,2,lObj.nframes,lObj.nTargets);
      pTrkTS = nan(obj.nPts,lObj.nframes,lObj.nTargets);      
      for iview=1:obj.nview
        t = trks(iview);
        if isfield(t,'pTrkFrm')
          frms = t.pTrkFrm;
        else
          frms = 1:size(t.pTrk,3);
          warningNoTrace('.pTrkFrm not present in trkfile, assuming leading frames.');
        end
        
        ipts = ipt2view==iview;
        pTrk(ipts,:,frms,:) = t.pTrk;
        pTrkTS(ipts,frms,:) = t.pTrkTS;
      end
      
      obj.trkP = pTrk;
      obj.trkPTS = pTrkTS;
    end
    function xy = getPredictionCurrentFrame(obj)
      % xy: [nPtsx2xnTgt], tracking results for all targets in current frm
      
      frm = obj.lObj.currFrame;
      xyPCM = obj.trkP;
      if isempty(xyPCM)
        npts = obj.nPts;
        nTgt = obj.lObj.nTargets;
        xy = nan(npts,2,nTgt);
      else
        % AL20160502: When changing movies, order of updates to 
        % lObj.currMovie and lObj.currFrame is unspecified. currMovie can
        % be updated first, resulting in an OOB currFrame; protect against
        % this.
        frm = min(frm,size(xyPCM,3));
        xy = squeeze(xyPCM(:,:,frm,:)); % [npt x d x ntgt]
      end
    end
  end
  
  %% Viz
  methods
    function vizInit(obj)
      deleteValidHandles(obj.hXYPrdRed); 
      obj.hXYPrdRed = []; 
      deleteValidHandles(obj.hXYPrdRedOther); 
      obj.hXYPrdRedOther = []; 
       
      % init .xyVizPlotArgs* 
      trackPrefs = obj.lObj.projPrefs.Track; 
      plotPrefs = trackPrefs.PredictPointsPlot; 
      plotPrefs.PickableParts = 'none'; 
      obj.xyVizPlotArgs = struct2paramscell(plotPrefs); 
      obj.xyVizPlotArgsNonTarget = obj.xyVizPlotArgs; % TODO: customize 
       
      npts = obj.nPts; 
      ptsClrs = obj.lObj.labelPointsPlotInfo.Colors; 
      ax = obj.ax; 
      %arrayfun(@cla,ax); 
      arrayfun(@(x)hold(x,'on'),ax); 
      ipt2View = obj.lObj.labeledposIPt2View; 
      hTmp = gobjects(npts,1); 
      hTmpOther = gobjects(npts,1); 
%       hTmp2 = gobjects(npts,1); 
      for iPt = 1:npts 
        clr = ptsClrs(iPt,:); 
        iVw = ipt2View(iPt); 
        hTmp(iPt) = plot(ax(iVw),nan,nan,obj.xyVizPlotArgs{:},'Color',clr); 
        hTmpOther(iPt) = plot(ax(iVw),nan,nan,obj.xyVizPlotArgs{:},'Color',clr);         
%         hTmp2(iPt) = scatter(ax(iVw),nan,nan); 
%         setIgnoreUnknown(hTmp2(iPt),'MarkerFaceColor',clr,... 
%           'MarkerEdgeColor',clr,'PickableParts','none',... 
%           obj.xyVizFullPlotArgs{:}); 
      end 
      obj.hXYPrdRed = hTmp; 
      obj.hXYPrdRedOther = hTmpOther; 
      obj.setHideViz(obj.hideViz); 
    end
    function setHideViz(obj,tf)
      onoff = onIff(~tf);
      [obj.hXYPrdRed.Visible] = deal(onoff);
      [obj.hXYPrdRedOther.Visible] = deal(onoff);
      obj.hideViz = tf;
    end
  end
  
  %% Labeler nav
  methods
    function newLabelerFrame(obj)
      lObj = obj.lObj;
      if lObj.isinit || ~lObj.hasMovie
        return;
      end
      
%       if obj.asyncPredictOn && all(isnan(xy(:)))
%         obj.asyncTrackCurrFrameBG();
%       end
      
      xy = obj.getPredictionCurrentFrame();    
      plotargs = obj.xyVizPlotArgs;
      itgt = lObj.currTarget;
      hXY = obj.hXYPrdRed;
      for iPt=1:obj.nPts
        set(hXY(iPt),'XData',xy(iPt,1,itgt),'YData',xy(iPt,2,itgt),plotargs{:});
      end
    end
    function newLabelerTarget(obj)
      obj.newLabelerFrame();
    end
    function newLabelerMovie(obj)
      obj.vizInit(); % not sure why this is nec
      if obj.lObj.hasMovie
        obj.trackCurrResUpdate();
        obj.newLabelerFrame();
      end
    end
  end
  
  %% Labeler listeners
  methods
    function labelerMovieRemoved(obj,edata)
      mIdxOrig2New = edata.mIdxOrig2New;
      tfLabeledRowRemoved = ~isempty(edata.mIdxRmedHadLbls);
      if tfLabeledRowRemoved
        warningNoTrace('Labeled row(s) removed from project. Clearing trained tracker and tracking results.');
        obj.initHook();
      else
        % relabel movie indices
        obj.movIdx2trkfile = mapKeyRemap(obj.movIdx2trkfile,mIdxOrig2New);
        
        % this might not be nec b/c the preds for current movie might not
        % ever change
        obj.trackCurrResUpdate();
        obj.newLabelerFrame();
      end      
    end
    function labelerMoviesReordered(obj,edata)
      mIdxOrig2New = edata.mIdxOrig2New;
      obj.movIdx2trkfile = mapKeyRemap(obj.movIdx2trkfile,mIdxOrig2New);
      
      % Assume trackCurrRes does not need update
    end
  end  
  
end