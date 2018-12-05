classdef BgTrainWorkerObjBsub < BgTrainWorkerObjLocalFilesys
    
  methods
    
    function obj = BgTrainWorkerObjBsub(nviews,dmcs)
      obj@BgTrainWorkerObjLocalFilesys(nviews,dmcs);
    end
    
    function killJob(obj,jID)
      % jID: scalar jobID
      
      bkillcmd = sprintf('bkill %d',jID);
      bkillcmd = DeepTracker.codeGenSSHGeneral(bkillcmd,'bg',false);
      fprintf(1,'%s\n',bkillcmd);
      [st,res] = system(bkillcmd);
      if st~=0
        warningNoTrace('Bkill command failed: %s',res);
      end
    end
    
    function fcn = makeJobKilledPollFcn(obj,jID)
      pollcmd = sprintf('bjobs -o stat -noheader %d',jID);
      pollcmd = DeepTracker.codeGenSSHGeneral(pollcmd,'bg',false);
      
      fcn = @lcl;
      
      function tf = lcl
        % returns true when jobID is killed
        %disp(pollcmd);
        [st,res] = system(pollcmd);
        if st==0
          tf = isempty(regexp(res,'RUN','once'));
        else
          tf = false;
        end
      end
    end
    
    function createKillToken(obj,killtoken)
      touchcmd = sprintf('touch %s',killtoken);
      touchcmd = DeepTracker.codeGenSSHGeneral(touchcmd,'bg',false);
      [st,res] = system(touchcmd);
      if st~=0
        warningNoTrace('Failed to create KILLED token: %s',killtoken);
      else
        fprintf('Created KILLED token: %s.\nPlease wait for your training monitor to acknowledge the kill!\n',killtoken);
      end
    end
    
  end
  
end
