classdef DLBackEndClass < handle
  % Placeholder class, future design unclear
  
  properties
    type  % scalar DLBackEnd
    awsec2 % used only for type==AWS
    
    % scalar logical. if true, backend runs code in APT.Root/deepnet. This
    % path must be visible in the backend or else.
    deepnetrunlocal = true; 
  end
 
  methods
    
    function obj = DLBackEndClass(ty)
      obj.type = ty;
    end
    
    function [tf,reason] = getReadyTrainTrack(obj)
      if obj.type==DLBackEnd.AWS
        aws = obj.awsec2;
        
        tf = ~isempty(aws);
        if ~tf
          reason = 'AWS EC2 instance is not configured.';
          return;
        end        
        
        [tfexist,tfrunning] = aws.inspectInstance;
        tf = tfrunning;
        if ~tf
          reason = sprintf('AWS EC2 instance %s is not running.',aws.instanceID);
          return;
        end
        
        reason = '';
      else
        tf = true;
        reason = '';
      end
    end
    
    function s = prettyName(obj)
      
      switch obj.type,
        case DLBackEnd.Bsub,
          s = 'JRC Cluster';
        case DLBackEnd.Docker,
          s = 'Local';
        otherwise
          s = char(obj.type);
      end
    end
 
  end
  
end
    