classdef APTParameters
  properties (Constant)
    PREPROCESS_PARAMETER_FILE = lclInitPreprocessParameterFile();
    TRACK_PARAMETER_FILE = lclInitTrackParameterFile();
    CPR_PARAMETER_FILE = lclInitCPRParameterFile();
    DEEPTRACK_PARAMETER_FILE = lclInitDeepTrackParameterFile();
    MDN_PARAMETER_FILE = lclInitDeepTrackMDNParameterFile();
    DLC_PARAMETER_FILE = lclInitDeepTrackDLCParameterFile();
    UNET_PARAMETER_FILE = lclInitDeepTrackUNetParameterFile();
  end
  methods (Static)
    function tPrm0 = defaultParamsTree
%       tPrmCpr = parseConfigYaml(APTParameters.CPR_PARAMETER_FILE);
%       tPrmDT = parseConfigYaml(APTParameters.DEEPTRACK_PARAMETER_FILE);
%       tPrm0 = tPrmCpr;
%       tPrm0.Children = [tPrm0.Children; tPrmDT.Children];

      tPrmPreprocess = parseConfigYaml(APTParameters.PREPROCESS_PARAMETER_FILE);
      tPrmTrack = parseConfigYaml(APTParameters.TRACK_PARAMETER_FILE);
      tPrmCpr = parseConfigYaml(APTParameters.CPR_PARAMETER_FILE);
      tPrmDT = parseConfigYaml(APTParameters.DEEPTRACK_PARAMETER_FILE);
      tPrmMdn = parseConfigYaml(APTParameters.MDN_PARAMETER_FILE);
      tPrmDlc = parseConfigYaml(APTParameters.DLC_PARAMETER_FILE);
      tPrmUnet = parseConfigYaml(APTParameters.UNET_PARAMETER_FILE);
      tPrmDT.Children.Children = [tPrmDT.Children.Children;...
        tPrmMdn.Children; tPrmDlc.Children; tPrmUnet.Children];        
      tPrm0 = tPrmPreprocess;
      tPrm0.Children = [tPrm0.Children; tPrmTrack.Children;...
        tPrmCpr.Children; tPrmDT.Children];
      tPrm0 = APTParameters.propagateLevelFromLeaf(tPrm0);
      tPrm0 = APTParameters.propagateRequirementsFromLeaf(tPrm0);
    end
    function sPrm0 = defaultParamsStruct
      % sPrm0: "new-style"
      
%       tPrmCpr = parseConfigYaml(APTParameters.CPR_PARAMETER_FILE);
%       sPrmCpr = tPrmCpr.structize();
%       sPrmCpr = sPrmCpr.ROOT;
%       tPrmDT = parseConfigYaml(APTParameters.DEEPTRACK_PARAMETER_FILE);
%       sPrmDT = tPrmDT.structize();
%       sPrmDT = sPrmDT.ROOT;
%       sPrm0 = structmerge(sPrmCpr,sPrmDT);

      tPrmPreprocess = parseConfigYaml(APTParameters.PREPROCESS_PARAMETER_FILE);
      sPrmPreprocess = tPrmPreprocess.structize();
      sPrmPreprocess = sPrmPreprocess.ROOT;
      
      tPrmTrack = parseConfigYaml(APTParameters.TRACK_PARAMETER_FILE);
      sPrmTrack = tPrmTrack.structize();
      sPrmTrack = sPrmTrack.ROOT;
      
      tPrmCpr = parseConfigYaml(APTParameters.CPR_PARAMETER_FILE);
      sPrmCpr = tPrmCpr.structize();
      sPrmCpr = sPrmCpr.ROOT;
      
      tPrmDT = parseConfigYaml(APTParameters.DEEPTRACK_PARAMETER_FILE);
      sPrmDT = tPrmDT.structize();
      sPrmDT = sPrmDT.ROOT;
      
      sPrm0 = structmerge(sPrmPreprocess,sPrmTrack,sPrmCpr,sPrmDT);
    end
    function sPrmDTcommon = defaultParamsStructDTCommon
      tPrm = parseConfigYaml(APTParameters.DEEPTRACK_PARAMETER_FILE);
      sPrm = tPrm.structize();
      sPrmDTcommon = sPrm.ROOT.DeepTrack;
    end
    function sPrmDTspecific = defaultParamsStructDT(nettype)
      switch nettype
        case DLNetType.mdn
          prmFile = APTParameters.MDN_PARAMETER_FILE;
        case DLNetType.deeplabcut
          prmFile = APTParameters.DLC_PARAMETER_FILE;
        case DLNetType.unet
          prmFile = APTParameters.UNET_PARAMETER_FILE;
        otherwise
          assert(false);
      end
      tPrm = parseConfigYaml(prmFile);
      sPrmDTspecific = tPrm.structize();
      sPrmDTspecific = sPrmDTspecific.ROOT;
      fld = fieldnames(sPrmDTspecific);
      assert(isscalar(fld)); % eg {'MDN'}
      fld = fld{1};
      sPrmDTspecific = sPrmDTspecific.(fld);
    end
    function ppPrm0 = defaultPreProcParamsOldStyle
      sPrm0 = APTParameters.defaultParamsOldStyle();
      ppPrm0 = sPrm0.PreProc;
    end
    function sPrm0 = defaultCPRParamsOldStyle
      sPrm0 = APTParameters.defaultParamsOldStyle();
      sPrm0 = rmfield(sPrm0,'PreProc');
    end
    function [tPrm,minLevel] = propagateLevelFromLeaf(tPrm)
      
      if isempty(tPrm.Children),
        minLevel = tPrm.Data.Level;
        return;
      end
      minLevel = PropertyLevelsEnum('Developer');
      for i = 1:numel(tPrm.Children),
        [tPrm.Children(i),minLevelCurr] = APTParameters.propagateLevelFromLeaf(tPrm.Children(i));
        minLevel = min(minLevel,minLevelCurr);
      end
      tPrm.Data.Level = PropertyLevelsEnum(minLevel);
      
    end
    function [tPrm,rqts] = propagateRequirementsFromLeaf(tPrm)
      
      if isempty(tPrm.Children),
        rqts = tPrm.Data.Requirements;
        return;
      end
      for i = 1:numel(tPrm.Children),
        [tPrm.Children(i),rqts1] = APTParameters.propagateRequirementsFromLeaf(tPrm.Children(i));
        if i == 1,
          rqts = rqts1;
        else
          rqts = intersect(rqts,rqts1);
        end
      end
      tPrm.Data.Requirements = rqts;
      
    end
    function filterPropertiesByLevel(tree,level)
      
      if isempty(tree.Children),
        tree.Data.Visible = tree.Data.Visible && tree.Data.Level <= level;
        return;
      end
      
      if tree.Data.Visible,
        tree.Data.Visible = false;
        for i = 1:numel(tree.Children),
          APTParameters.filterPropertiesByLevel(tree.Children(i),level);
          tree.Data.Visible = tree.Data.Visible || tree.Children(i).Data.Visible;
        end
      end
      
    end
    
    function tree = setAllVisible(tree)
      
      tree.Data.Visible = true;
      for i = 1:numel(tree.Children),
        APTParameters.setAllVisible(tree.Children(i));
      end
      
    end
    
    function tree = filterPropertiesByCondition(tree,labelerObj)
    
      if isempty(tree.Children),
      
        if ismember('isCPR',tree.Data.Requirements) && ~strcmpi(labelerObj.trackerAlgo,'cpr'),
          tree.Data.Visible = false;
        elseif ismember('hasTrx',tree.Data.Requirements) && ~labelerObj.hasTrx,
          tree.Data.Visible = false;
        elseif ismember('isDeepTrack',tree.Data.Requirements) && ~labelerObj.trackerIsDL,
          tree.Data.Visible = false;
        elseif ismember('isMDN',tree.Data.Requirements) && ~strcmp(labelerObj.trackerAlgo,'mdn'),
          tree.Data.Visible = false;
        elseif ismember('isDeepLabCut',tree.Data.Requirements) && ~strcmp(labelerObj.trackerAlgo,'deeplabcut'),
          tree.Data.Visible = false;
        elseif ismember('isUnet',tree.Data.Requirements) && ~strcmp(labelerObj.trackerAlgo,'unet'),
          tree.Data.Visible = false;        
        end
        
        return;
        
      end
        
      if tree.Data.Visible,
        tree.Data.Visible = false;
        for i = 1:numel(tree.Children),
          APTParameters.filterPropertiesByCondition(tree.Children(i),labelerObj);
          tree.Data.Visible = tree.Data.Visible || tree.Children(i).Data.Visible;
        end
      end
      
    end
    
    function [sPrm,tfChangeMade] = enforceConsistency(sPrm)
      % enforce constraints amongst complete NEW-style parameters
      %
      % sPrm (in): input full new-style param struct
      % 
      % sPrm (out): output params, possibly massaged. If massaged, warnings
      % thrown
      % tfChangeMade: if any changes made
      
      % TODO: reconcile with paramChecker, ParameterTreeConstraint
      
      tfChangeMade = false;
      
      if sPrm.ROOT.ImageProcessing.MultiTarget.TargetCrop.AlignUsingTrxTheta && ...
         strcmp(sPrm.ROOT.CPR.RotCorrection.OrientationType,'fixed')
        warningNoTrace('CPR OrientationType cannot be ''fixed'' if aligning target crops using trx.theta. Setting CPR OrientationType to ''arbitrary''.');
        sPrm.ROOT.CPR.RotCorrection.OrientationType = 'arbitrary';
        tfChangeMade = true;
      end
    end
    
  end
  methods (Static)
    function sPrm0 = defaultParamsOldStyle
      tPrm0 = APTParameters.defaultParamsTree;
      sPrm0 = tPrm0.structize();
      % Use nan for npts, nviews; default parameters do not know about any
      % model
      sPrm0 = CPRParam.new2old(sPrm0,nan,nan);
    end
  end
end

function preprocessParamFile = lclInitPreprocessParameterFile()
aptroot = APT.Root;
preprocessParamFile = fullfile(aptroot,'params_preprocess.yaml');
end
function trackParamFile = lclInitTrackParameterFile()
aptroot = APT.Root;
trackParamFile = fullfile(aptroot,'params_track.yaml');
end
function cprParamFile = lclInitCPRParameterFile()
aptroot = APT.Root;
cprParamFile = fullfile(aptroot,'trackers','cpr','params_cpr.yaml');
%cprParamFile = fullfile(aptroot,'trackers','cpr','params_apt.yaml');
end
function dtParamFile = lclInitDeepTrackParameterFile()
aptroot = APT.Root;
dtParamFile = fullfile(aptroot,'trackers','dt','params_deeptrack.yaml');
end
function dtParamFile = lclInitDeepTrackMDNParameterFile()
aptroot = APT.Root;
dtParamFile = fullfile(aptroot,'trackers','dt','params_deeptrack_mdn.yaml');
end
function dtParamFile = lclInitDeepTrackDLCParameterFile()
aptroot = APT.Root;
dtParamFile = fullfile(aptroot,'trackers','dt','params_deeptrack_dlc.yaml');
end
function dtParamFile = lclInitDeepTrackUNetParameterFile()
aptroot = APT.Root;
dtParamFile = fullfile(aptroot,'trackers','dt','params_deeptrack_unet.yaml');
end
