classdef MMTableMulti < MovieManagerTable
  
  properties
    nmovsPerSet
    tbl % treeTable
  end
  properties (Constant)
    HEADERS = {'Set' 'Movie' 'Has Labels'};
    COLTYPES = {'' 'char' 'logical'};
    COLEDIT = {false false false};
    COLWIDTHS = containers.Map({'Movie','Has Labels'},{600,250});
  end
  
  methods
    
    function obj = MMTableMulti(nMovsPerSet,hParent,position,cbkSelectMovie)
      obj@MovieManagerTable(hParent,position,cbkSelectMovie);
      obj.nmovsPerSet = nMovsPerSet;      
    end
    
    function updateMovieData(obj,movNames,trxNames,movsHaveLbls)
      nSets = size(movNames,1);
      assert(size(movNames,2)==obj.nmovsPerSet);
      assert(nSets==numel(movsHaveLbls));
      
      iSet = repmat(1:nSets,obj.nmovsPerSet,1);
      movNames = movNames';
      movsHaveLbls = repmat(movsHaveLbls(:),1,obj.nmovsPerSet);
      movsHaveLbls = movsHaveLbls';
      dat = [num2cell(iSet(:)) movNames(:) num2cell(movsHaveLbls(:))];
      
      tt = treeTable(obj.hParent,obj.HEADERS,dat,...
        'ColumnTypes',obj.COLTYPES,...
        'ColumnEditable',obj.COLEDIT,...
        'Groupable',true,...
        'IconFilenames',...
            {'' fullfile(matlabroot,'/toolbox/matlab/icons/file_open.png') fullfile(matlabroot,'/toolbox/matlab/icons/foldericon.gif')});
      cwMap = obj.COLWIDTHS;
      keys = cwMap.keys;
      for k=keys(:)',k=k{1}; %#ok<FXSET>
        tblCol = tt.getColumn(k);
        tblCol.setPreferredWidth(cwMap(k));
      end
      
      tt.MouseClickedCallback = @(s,e)obj.cbkClickedDefault(s,e);
      tt.setDoubleClickEnabled(false);
      obj.tbl = tt;
    end
  
    function updateSelectedMovie(obj,imov)
      % imov is the movie SET (1-based)
      %
      % Collapse all rows, expand the selected set
      
      tt = obj.tbl;
      m = tt.getModel;
      m.collapseAll;
      
      iRowForSet = imov-1; % 0-based;
      
      if iRowForSet<0 || iRowForSet>=tt.getRowCount()
        % iRowForSet can be <- when starting up (no movies)
        % iRowForSet can be >= tt.getRowCount()-1 when removing a movie;
        % don't do anything
        return;
      end
        
      iRowForSet = min(iRowForSet,tt.getRowCount()-1);
      row = tt.getRowAt(iRowForSet);
      tt.setSelectedRow(row);
      m.expandRow(row,true);
    end

    function imovs = getSelectedMovies(obj)
      % imovs: [nsel] selected movie SETS (1-based)
      %
      % AL20160630: IMPORTANT: currently CANNOT sort table by columns      
      
      tt = obj.tbl;
      selRow = tt.getSelectedRows;
      imovs = zeros(0,1);
      for row=selRow(:)'
        rObj = tt.getRowAt(row);
        while ~isempty(rObj) && ~isa(rObj,'com.jidesoft.grid.DefaultGroupRow')
          rObj = get(rObj,'Parent');
        end
        if ~isempty(rObj)
          setstr = char(rObj);
          tmp = regexp(setstr,'Set: (?<set>[0-9]+)','names');
          if ~isempty(tmp)
            setno = str2double(tmp.set);
            imovs(end+1,1) = setno; %#ok<AGROW>
          end
        else
          warning('MMTableMulti:row','Could not find set/parent for row ''%d''.',row);
        end
      end
      imovs = unique(imovs);
    end
   
  end
end