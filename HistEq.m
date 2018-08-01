classdef HistEq
  
  methods (Static)
    
    function [hgramsel,info] = selMovCentralImHist(cntmat,varargin)
      % Select a movie with a central/median imhist
      %
      % cntmat: [nbin x nmovset x nvw]. cntmat(:,imov,ivw) contains the
      %   imhist for the given movie/view. 
      %   Typically this will be generated by sampling the given movie.
      %   cntmat need not be normalized ie sum(cntmat(:,imov,ivw)) does not
      %   need to be constant over imov,ivw.
      %
      % hgramsel: [nbin x nvw] imhist counts (raw, not normalized) for
      %   selected movie in each view
      % info: struct with diagnostic info
      
      debugviz = myparse(varargin,...
        'debugviz',false... % set to true for a debug/viz plot
        );
      
      if isempty(cntmat)
        error('Input count matrix cannot be empty.');
      end
      
      [nbin,nmov,nvw] = size(cntmat);
      
      cntmatsum = sum(cntmat,1);
      cntmatnorm = cntmat./repmat(cntmatsum,[nbin 1 1]); % don't assume autobsx 16b
      cntmatnormcum = cumsum(cntmatnorm,1); % [nbin x nmov x nvw]. columns are imhist CDFs with final el==1
      
      cntmatnormcummdn = median(cntmatnormcum,2); % [nbin x 1 x nvw]
      % metric is sum(abs(d_cumulativeimhist))
      cntmatdst = sum(abs(cntmatnormcum-repmat(cntmatnormcummdn,1,nmov,nvw)),1); % [1 x nmov x nvw]
      cntmatdst = reshape(cntmatdst,nmov,nvw)/nbin; % [nmov x nvw]. average value of d_normalizedCDF over bins
      [cntmatdstsorted,imovssorted] = sort(cntmatdst,1);
      
      imovsel = imovssorted(1,:);
      hgramsel = nan(nbin,nvw);
      for ivw=1:nvw
        hgramsel(:,ivw) = cntmat(:,imovsel(ivw),ivw);
      end
      info = struct();
      info.imovsel = imovsel;

      if debugviz
        figure;
        axs = mycreatesubplots(nvw,2,.1); % col1: imhist. col2: cdf
        for ivw=1:nvw
          ax = axs(ivw,2);
          axes(ax);
          bins = 1:nbin;
          plot(bins,cntmatnormcum(:,:,ivw));
          hold on
          hplot(1) = plot(bins,cntmatnormcummdn(:,:,ivw),'r-','linewidth',2);
          hplot(2) = plot(bins,cntmatnormcum(:,imovsel(ivw),ivw),'b-','linewidth',2);
          grid on;
          if ivw==1
            legend(hplot,'median','selected');
          end
          
          fprintf('best imhist distances:\n');
          tmp = cntmatdstsorted(:,ivw);
          tmp = tmp(1:min(end,10));
          disp(tmp);
          
          ax = axs(ivw,1);
          axes(ax);
          plot(bins,log10(cntmatnorm(:,:,ivw)));
          hold on;
          plot(bins,log10(cntmatnorm(:,imovsel(ivw),ivw)),'b-','linewidth',2);
          tstr = sprintf('imhist, %d movs, view%d',nmov,ivw);
          title(tstr,'fontweight','bold');
          grid on;
        end
      end
    end
    
    function [lut,J] = genHistEqLUT(I,hgram,varargin)
      % Generate LUT that performs histeq for imageset based on samples
      %
      % I: (big) image
      % hgram: [nbin] desired/target imhist counts for equally-spaced bins.
      %   hgram need not be normalized ie sum(hgram) can be anything. The 
      %   bin edges/locs implied by hgram depend on the class/type of
      %   images in I. See doc for builtin histeq.
      %
      % lut: [2^bitDepth] vector. The lut which, when applied to I, gives
      %   an output image J with approximately the desired hgram, ie 
      %   J = lut(uint32(I)+1)
      % J: I, transformed by lut
      
%       sz = cellfun(@size,Is,'uni',0);
%       sz = cat(1,sz{:});
%       sz = unique(sz,'rows');
%       assert(size(sz,1)==1,'Images do not all have the same size.');
%       assert(numel(sz)==2,'Images must be single-channel intensity images.');
      
%       Ibig = cat(1,Is{:});

      docheck = myparse(varargin,...
        'docheck',false);

      bitDepth = HistEq.imCls2BitDepth(I);
      [J,T] = histeq(I,hgram);
      lut = HistEq.histeqT2LUT(T,bitDepth);
      
      if docheck
        fprintf(1,'Performing LUT check.\n'); % remove me at some pt
        Iidx = uint32(I)+1; % otherwise adding 1 may saturate
        assert(isequal(J,lut(Iidx)));
      end
    end
    
    function lut = histeqT2LUT(T,bitDepth)
      % Convert the T output arg from histeq() into a lookup table
      % T: double vec, each el in [0,1]
      %
      % Reverse-engineered. Personally seems weird given the treatment 
      % of endpoints, but prob there is some good reason for it.
      
      nT = numel(T);
      N = 2^bitDepth;

      idx = (0:N-1)/(N-1)*(nT-1); % [N] vector equally spaced taking vals 0 .. nT-1
      idx = round(idx);
      lut = T(idx+1);
      lut = round(lut(:)*(N-1));      
    end
    
    function bitDepth = imCls2BitDepth(I)
      clsI = class(I);
      switch clsI
        case 'uint8'
          bitDepth = 8;
        case 'uint16'
          bitDepth = 16;
        otherwise
          error('Unsupported for images of type ''%s''.',clsI);
      end
    end
        
    function [im,hgram,j,t,lut,tlut] = testRevEng(bitDepth)
      % Reverse-engineer how we are supposed to use matlab's grayscale
      % transformation T, cause I mean how else would we know. Geesh.
      
      switch bitDepth
        case 8
          imcls = 'uint8';
        case 16
          imcls = 'uint16';
        otherwise
          assert(false);
      end
      
      N = 2^bitDepth;
      im = feval(imcls,(0:N-1))';
      im = reshape(im,sqrt(N),sqrt(N));
      hgram = rand(1,50);      
      [j,t] = histeq(im,hgram);
      lut = nan(N,1);
      for i=0:N-1
        idx = im==i;
        jidx = j(idx);
        jidx = unique(jidx);
        assert(isscalar(jidx));
        lut(i+1) = jidx;
      end
      
      tlut = HistEq.histeqT2LUT(t,bitDepth);      
      if isequal(lut,tlut)
        fprintf(1,'Reverse-engineered LUT matches\n');
      else
        assert(false,'Reverse-engineered LUT doesn''t match');
      end
    end
    
    function test
      imdatadir = fullfile(matlabroot,'toolbox','images','imdata');
      dd = dir(imdatadir);
      dd = dd(3:end);

      hgram = rand(1,50);
      for i=1:numel(dd)
        imfile = fullfile(imdatadir,dd(i).name);
        try
          im = imread(imfile);
        catch ME
          fprintf('%s. Failed to read: %s\n',dd(i).name,ME.message);
          continue;
        end
        switch class(im)
          case {'uint8' 'uint16'}
            nchan = size(im,3);
            if size(im,3)>1
              im = rgb2gray(im);
            end
            lut = HistEq.genHistEqLUT(im,hgram,'docheck',true); 
            fprintf('OK %s. class=%s. nchan=%d, numel(lut)=%d\n',...
              dd(i).name,class(im),nchan,numel(lut));
        end
      end      
    end

  end

  
end