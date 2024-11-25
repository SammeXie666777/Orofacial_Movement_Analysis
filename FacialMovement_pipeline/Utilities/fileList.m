classdef fileList < handle
    properties 
        fileName % fileName 
    end

    methods 
        function fileObj =  fileList(fileName)
            % Constructor: create multiple file objects
            arguments
                fileName (1,:) = "";
            end 
            if ischar(fileName)
               fileName = cellstr(fileName);
            end
            for i = 1:numel(fileName)
                fileObj(i).fileName = fileName{i};
            end
        end

        function fileListCell = convertFileToCell (fileObj)
            fileListCell = cell(1, numel(fileObj));
            for i = 1:numel(fileObj)
                fileListCell{i} = fileObj(i).fileName;
            end
        end


        function [outputFile] = makeOutputFileList (fileObj,fileLocation,keyWord,changeNameorNot)
            % Method: Make output fileName list
            % Make sure no name the same as in same directory
            arguments
                fileObj (1,:) fileList
                fileLocation (1,1) {mustBeMember (fileLocation,{'originalFolder','NewFolder'})}
                keyWord (1,:) cell
                changeNameorNot (1,1) {mustBeMember (changeNameorNot,{'ChangetoLegalName','NoChange'})}
            end
            
            outputFile = cell(1,numel(fileObj));
            for i = 1:numel(fileObj)
                [directory, name, ext] = fileparts(fileObj(i).fileName); 
                if strcmp(changeNameorNot,ChangetoLegalName)
                name = matlab.lang.makeValidName(name);
                end
                if strcmp(fileLocation,'NewFolder')
                    directory = uigetdir('', 'Select directory for output files');
                    if directory == 0
                        disp('No directory selected. Output files list not created.');
                        return;
                    end
                end

                if ~isempty(keyWord)
                    name = strjoin([{name},keyWord]);
                end
                
                % Check if name exist in current folder
                files = dir(directory);
                fileNames = {files(~[dir(directory).isdir]).name};
                if any(strcmp(fileNames, outputFile{i}))
                    warning ('Constructed fileName coincide with existing files in the current directory');
                    time = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
                    name = [name,'_',time];
                end 
                outputFile{i} = fullfile(directory, [name, ext]);
            end
        end
        
        function NewfileList = changeFileKeyword (fileObj,renameOriginalFileorNot,OGkeyword,Newkeyword)
            arguments
                fileObj fileList
                renameOriginalFileorNot (1,1)  {mustBeMember (renameOriginalFileorNot,[0,1])}
                OGkeyword cell
                Newkeyword cell
            end
            NewfileList = cell(1,numel(fileObj));
            for i = 1:numel(fileObj)
                oldname = fileObj(i).fileName;
                if contains(oldname,OGkeyword{:})
                    NewfileList{i} = strrep(oldname, OGkeyword{:}, Newkeyword{:});
                else
                    warning('No keyword %s in file %s',OGkeyword{:},oldname);
                end
                if renameOriginalFileorNot == 1
                    if ~isempty(NewfileList{i})
                    movefile(oldname, NewfileList{i});  
                    end
                end                
            end
        end

    end

    methods (Static)
        function [fileObj] = pullFilesUserInput(fileExt, mutiselectOnorOff,defaultDir)
            arguments
                fileExt string {mustBeMember(fileExt, [".m", ".mp4", ".fig", ".mat", ".h5","*.*"])} 
                mutiselectOnorOff {mustBeMember (mutiselectOnorOff, ["on","off"])} = "on"
                defaultDir string = "" % Can be a directory path
            end            
            % Construct file filter string for uigetfile
            filterString = "";
            for i = 1:length(fileExt)
                if i == 1
                    filterString = strcat('*', fileExt(i));
                else
                    filterString = strcat(filterString, ';*', fileExt(i));
                end
            end

            if isempty(defaultDir)
                [fileNames, filePath] = uigetfile(filterString, 'Select one or more files', 'MultiSelect', mutiselectOnorOff);  
            else
                [fileNames, filePath] = uigetfile(filterString, 'Select one or more files', defaultDir, 'MultiSelect', mutiselectOnorOff);  
            end

            if isequal(fileNames, 0)
                disp('User selected Cancel');
                fileObj = [];
            else
                if iscell(fileNames) % if multiple files are selected
                    fileObj = repmat(fileList, length(fileNames), 1);
                    for i = 1:length(fileNames)
                        fileObj(i) = fileList(fullfile(filePath, fileNames{i}));
                        disp(['Selected file: ' fileObj(i).fileName]);
                    end
                else
                    fileObj = fileList(fullfile(filePath, fileNames));
                    disp(['Selected file: ' fileObj.fileName]);
                end
            end
        end

        function newPath = translatePath(originalPath, windowbase, macbase)
            % Function to translate file paths between macOS and Windows
            arguments
                originalPath (1,:) cell
                windowbase string = 'Z:'
                macbase string = '/Volumes/djlab1_root';
            end
            
            newPath = cell(size(originalPath));
            for i = 1:numel(originalPath)
                ogpath = originalPath{i};
                
                if ispc
                    newBaseDrive = windowbase;  % Windows mount point
                    oldBaseDrive = macbase;     % macOS mount point to be replaced
                    fileSeparator = '\';        % Windows file separator
                elseif ismac
                    newBaseDrive = macbase; 
                    oldBaseDrive = windowbase; 
                    fileSeparator = '/'; 
                else
                    error('Unsupported operating system');
                end
                
                % Replace the old base with the new one
                if contains(ogpath, oldBaseDrive)
                    translatedPath = strrep(ogpath, oldBaseDrive, newBaseDrive);
                    translatedPath = strrep(translatedPath, '/', fileSeparator);
                    translatedPath = strrep(translatedPath, '\', fileSeparator);
                    newPath{i} = translatedPath;
                else
                    newPath{i} = ogpath;
                end
            end
        end


        function [diffPath, idx] = findDiffFile(pathList1, pathList2)
            % Find file names in pathList2 that are not in pathList1:
            % Compare only file name
            arguments
                pathList1 (1, :) cell
                pathList2 (1, :) cell
            end
            pathList1 = fileList.translatePath(pathList1); % Current OS
            pathList2 = fileList.translatePath(pathList2);
        
            name1 = cell(1, numel(pathList1));
            name2 = cell(1, numel(pathList2));
            for i = 1:numel(pathList1)
                [~, name1{i}, ~] = fileparts(pathList1{i});
            end
            for i = 1:numel(pathList2)
                [~, name2{i}, ~] = fileparts(pathList2{i});
            end

            if isscalar(name1) && isscalar(name2) % One file for both input
                if strcmp(name1{1}, name2{1})
                    diffPath = [];
                    idx = 1; 
                else
                    diffPath = pathList2;  
                    idx = 0;
                end
                return;
            end
            % Diff files
            name1 = cellfun(@char, name1, 'UniformOutput', false);
            name2 = cellfun(@char, name2, 'UniformOutput', false);
            uniqueNames = setdiff(name2, name1, 'stable');
            if isempty(uniqueNames) % Same input
                diffPath = [];
                idx = [];
            else
                diffPath = cell(1, numel(uniqueNames));
                idx = zeros(1, numel(uniqueNames));
                for i = 1:numel(uniqueNames)
                    loc = find(strcmp(uniqueNames{i}, name2));
                    diffPath{i} = pathList2{loc(1)};  % Pick the first occurrence
                    idx(i) = loc(1);
                end
            end        
            diffPath = fileList.translatePath(diffPath);
        end

       function [fileNamPairObj,newName,oldPath] = renameFileNames(fileList,renameOriginalFileorNot,keywords,renameEachFileorNot) 
            % Method: rename files in the original directory
            % Output: oldpath (full path); newName (file name only)
            arguments
                fileList (1,:) cell
                renameOriginalFileorNot (1,1)  {mustBeMember (renameOriginalFileorNot,[0,1])}
                keywords (1,:) cell = {}
                renameEachFileorNot (1,1) {mustBeMember (renameEachFileorNot,[0,1])} = 0
            end
            newName = cell(1,numel(fileList));
            oldPath = cell(1,numel(fileList));
            partsTobeKept = cell(1,numel(fileList));
            fileNamPairObj = PairMapper();
            for i = 1:numel(fileList)
                [~,exName,~] = fileparts(fileList{i});
                fprintf('Current file name: %s \n',exName);
                parts = strsplit(exName,'_');
                for j = 1:numel(parts)
                    fprintf('FileName part %d = %s \n', j,parts{j});
                end
                partsTobeKept{i} = input('Enter the id of parts of the file to be preserved. Enter 0 for No parts (for multiple parts, write like [1,2,3]): ');
                if renameEachFileorNot == 0
                    [partsTobeKept{1:end}] = deal(partsTobeKept{i});
                    break
                end
            end

            for i = 1:numel(fileList)
                oldPath{i}=fileList{i};
                [dir,oldName,ext] = fileparts(fileList{i});                
                if partsTobeKept{i} ~= 0
                    tempParts = strsplit(oldName,'_');
                    tempParts = tempParts(partsTobeKept{i}); % cell of parts
                else
                    tempParts = {};
                end
                if ~isempty(keywords)
                    tempParts = [keywords,tempParts];
                end
                
                if (any(partsTobeKept{i} == 0) && isempty(keywords)) || isempty(partsTobeKept{i})
                    newName{i} = oldName;
                else
                    newName{i} = strjoin(tempParts,'_');
                end
                newName{i} = matlab.lang.makeValidName(newName{i});

                newPath{i} = fullfile(dir,[newName{i},ext]);
                
                if renameOriginalFileorNot == 1 
                    movefile(oldPath{i}, newPath{i});                    
                end
            end
            fileNamPairObj = addMapping(fileNamPairObj,newPath,oldPath);
        end


    end    
    
end      

    


