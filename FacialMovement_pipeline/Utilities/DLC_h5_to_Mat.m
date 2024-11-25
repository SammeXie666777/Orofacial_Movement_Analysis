    
    % Aurelie 2/9/2023; Samme Xie edited 08/24
    % Matlab R2024a
    %
    % Create a mat file containing the position (x,y) of each marker and
    % its probability (markerpos.markername.x,markerpos.markername.y,markerpos.markername.p)
    %
    % This code calls an external function named yaml.loadFile that is part
    % of a set of functions made to interact with yaml files that should be
    % downloaded here:
    % https://www.mathworks.com/matlabcentral/fileexchange/106765-yaml.
    % These only work for MATLAB R2019b or newer releases.
    %%%%%%%%%%%%%%%%%%%%% 
function [output,markerlabels] = DLC_h5_to_Mat (h5path,configpath,dirorfile)
    
    % h5path: directory containing h5 files or direct path to a selection
    %         of h5 files
    % configpath: path to config yaml file
    % dirorfile: indicta h5path input is a directory or path names
 
    cd(configpath)
    datyaml = yaml.loadFile('config.yaml');
    markerlabels = datyaml.bodyparts;
    if strcmp(markerlabels,'MULTI!')
        markerlabels = datyaml.multianimalbodyparts;
    end
    if strcmp(dirorfile,'direc')
        cd(h5path);
        h5files = dir('*.h5');
        matnames = {dir('*.mat').name};
        movlist = {};
        for i = 1:length(h5files)
            ids = strfind(h5files(i).name, 'DLC');
            expectedMatName = [h5files(i).name(1:ids-1) '_markerPos.mat'];
            if ~any(strcmp(matnames, expectedMatName))
                movlist{end+1} = h5files(i).name; 
            end
        end

    elseif strcmp(dirorfile,'file')
        movlist = h5path; % full h5 file as cell
    end
    output = cell(1,length(movlist));
    for i=1:length(movlist)
        markerposh5 = getStructure(movlist{i});
        markerpos = struct;
        for j=1:length(markerlabels)
            temp.x = markerposh5.values_block_0(3*j-2,:);
            temp.y = markerposh5.values_block_0(3*j-1,:);
            temp.p = markerposh5.values_block_0(3*j,:);
            markerpos.(markerlabels{j})=temp;
        end

        %save
        [direc,name,~] = fileparts(movlist{i});
        ids = strfind(name,'DLC');
        filename = fullfile(direc,[name(1:ids-1)  '_markerPos.mat']);
        output{i} = filename;
        save(filename,'markerpos')
    end
end

% Troubleshoot 
function markerposh5 = getStructure(h5name)
    info = h5info(h5name);
    % Loop through groups to find the dataset
    found = false;
    for g = 1:length(info.Groups)
        subgroupInfo = h5info(h5name, info.Groups(g).Name);
        if any(strcmp({subgroupInfo.Datasets.Name}, 'table'))
            % If found, read the data
            markerposh5 = h5read(h5name, fullfile(info.Groups(g).Name, 'table'));
            found = true;
            break;
        end
    end
    
    if ~found
        warning('Dataset "table" not found in any group of %s', h5name);
        markerposh5 = [];
    end
end