function ROI = GUI_Cropping(vdpath, defaultWidthHeight, ROI_names, opt)
    % Input: vdpath: string
    % defaultWidthHeight = [] or cell array {[width1, height1], [], [width3, height3], ...}
    % opt = 1 or 0: 1 save output
    % ROI_names = empty: single ROI with a generic subfield 'ROI'
    %           = cell array of strings: names for multiple ROIs
    % Output: ROI.(ROInames).X/Y/Width/Height/TotalArea/VideoPath

    if isempty(vdpath)
        vdpath = fileList.pullFilesUserInput(".mp4","off");
        vdpath = vdpath.fileName;
    else
        if ~isfile(vdpath) % Check if the input video path is valid
            error('The specified video file does not exist.');
        end
    end
     
    % Check defaultWidthHeight and ROI_names
    if ischar(ROI_names) || isstring(ROI_names)
        ROI_names = {ROI_names};
    end
    
    if isempty(defaultWidthHeight)
        % defaultWidthHeight is empty, create cell array of empties
        defaultWidthHeight = cell(1, length(ROI_names));
    elseif iscell(defaultWidthHeight)
        if length(defaultWidthHeight) ~= length(ROI_names)
            error('Number of defaultWidthHeight entries must match number of ROI_names.');
        end
    elseif isnumeric(defaultWidthHeight)
        if size(defaultWidthHeight,1) ~= length(ROI_names)
            error('Number of rows in defaultWidthHeight must match number of ROI_names.');
        end
        defaultWidthHeight = num2cell(defaultWidthHeight, 2); % Convert to cell array
    else
        error('defaultWidthHeight must be empty, a cell array, or a numeric matrix.');
    end

    % GUI setup
    hFig = figure('Name', 'Interactive Video Cropping', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none', 'CloseRequestFcn', @closeFig);
    setappdata(hFig, 'ResumeWait', false); % Flag to control the wait status
    hAx = axes('Parent', hFig, 'Units', 'normalized', 'Position', [0.1, 0.2, 0.8, 0.7]);

    hROIList = uicontrol('Style', 'listbox', 'Parent', hFig, 'Units', 'normalized', ...
                         'Position', [0.92, 0.2, 0.07, 0.7], 'String', {}, 'Callback', @selectROI, 'Value', 1);
    hWidthText = uicontrol('Style', 'text', 'Parent', hFig, 'Units', 'normalized', ...
                          'Position', [0.1, 0.15, 0.1, 0.05], 'String', 'Width:');
    hWidthInput = uicontrol('Style', 'edit', 'Parent', hFig, 'Units', 'normalized', ...
                          'Position', [0.2, 0.15, 0.1, 0.05], 'String', '', 'Callback', @updateROI);
    hHeightText = uicontrol('Style', 'text', 'Parent', hFig, 'Units', 'normalized', ...
                          'Position', [0.3, 0.15, 0.1, 0.05], 'String', 'Height:');
    hHeightInput = uicontrol('Style', 'edit', 'Parent', hFig, 'Units', 'normalized', ...
                          'Position', [0.4, 0.15, 0.1, 0.05], 'String', '', 'Callback', @updateROI);
    hAreaText = uicontrol('Style', 'text', 'Parent', hFig, 'Units', 'normalized', ...
                          'Position', [0.5, 0.15, 0.2, 0.05], 'String', 'Area: 0');
    hCompleteBtn = uicontrol('Style', 'pushbutton', 'String', 'Complete', 'Units', 'normalized', ...
                             'Position', [0.1, 0.92, 0.1, 0.05], 'Callback', @completeCallback);
    hAddROIBtn = uicontrol('Style', 'pushbutton', 'String', 'Add ROI', 'Units', 'normalized', ...
                           'Position', [0.22, 0.92, 0.1, 0.05], 'Callback', @addROICallback);
    hDeleteROIBtn = uicontrol('Style', 'pushbutton', 'String', 'Delete ROI', 'Units', 'normalized', ...
                              'Position', [0.34, 0.92, 0.1, 0.05], 'Callback', @deleteROICallback);
    hROIs = struct();
    hROI = []; % Initialize hROI
    ROI = struct(); % Initialize ROI as an empty structure

    videoObj = VideoReader(vdpath);
    frame = readFrame(videoObj); % Extract the first frame from the video
    frameSize = size(frame);
    frameWidth = frameSize(2);
    frameHeight = frameSize(1);
    clearvars videoObj
    imshow(frame, 'Parent', hAx); % Display the first frame
    title(hAx, 'First Frame');
    drawnow;

    % Draw initial ROIs from the video if they already exist
    if iscell(ROI_names)
        set(hROIList, 'String', ROI_names);
        for i = 1:length(ROI_names)
            hROIs.(ROI_names{i}) = []; % Initialize empty fields in hROIs for each name
            set(hROIList, 'Value', i); % Select the current ROI in the list
            fprintf('Draw ROI for %s \n', ROI_names{i});
            % Pass defaultWidthHeight{i} to createROI()
            createROI(defaultWidthHeight{i});
            hROIs.(ROI_names{i}) = hROI; % Store the drawn ROI
        end
    elseif isempty(ROI_names)
        set(hROIList, 'String', {'ROI'});
        hROIs.ROI = [];
        fprintf('Draw ROI \n');
        % Use the first element of defaultWidthHeight or empty if not provided
        if isempty(defaultWidthHeight)
            createROI([]);
        else
            createROI(defaultWidthHeight{1});
        end
        hROIs.ROI = hROI; % Assign the created ROI to the "ROI" field
    else
        error('Invalid ROI_names input. It must be empty, a string, or a cell array of ROI names.');
    end

    disp('Waiting for user interaction...');
    while ~getappdata(hFig, 'ResumeWait')
        uiwait(hFig);
    end
    delete(hFig);
    disp('User interaction completed.');

    %% Nested functions with debugging
    function completeCallback(~, ~)
        disp('Complete button pressed.');
        roiNames = get(hROIList, 'String');
        if isempty(roiNames)
            warndlg('No ROIs defined. Please add at least one ROI before completing.', 'No ROIs');
            return;
        end
        choice = questdlg('Do you want to complete the selection?', 'Complete Selection', 'Yes', 'No', 'Yes');
        if strcmp(choice, 'Yes')
            disp('Completing selection...');
            ROI = struct(); % Assign ROI only within this block
            for i = 1:length(roiNames)
                roiName = roiNames{i};
                if isfield(hROIs, roiName) && ~isempty(hROIs.(roiName)) &&  isvalid(hROIs.(roiName))
                    position = hROIs.(roiName).Position;
                    ROI.(roiName) = struct('X', position(1), 'Y', position(2), 'Width', position(3), 'Height', position(4), 'TotalArea', position(3) * position(4), 'OriginalVideoPath', vdpath);
                end
            end
            if opt == 1 % Save only when this == 1
                [dir,~,~] = fileparts (vdpath);
                matFileName = fullfile(dir,'CroppingParameters.mat');
                save(matFileName, 'ROI');
            end
            fprintf('Selected ROIs for %s:\n', vdpath);
            fields = fieldnames(ROI);
            for i = 1:length(fields)
                fprintf('[Name: %s, X: %.2f, Y: %.2f, Width: %.2f, Height: %.2f, TotalArea: %.2f]\n', ...
                    fields{i}, ROI.(fields{i}).X, ROI.(fields{i}).Y, ROI.(fields{i}).Width, ROI.(fields{i}).Height, ROI.(fields{i}).TotalArea);
            end
            setappdata(hFig, 'ResumeWait', true); % Set flag to true
            uiresume(hFig); % Resume the execution
            disp('GUI closed.');
        end
    end

    function closeFig(~, ~)
        choice = questdlg('Do you want to complete the selection?', 'Close Request', 'Yes', 'No', 'Exit', 'Exit');
        if strcmp(choice, 'Yes')
            completeCallback();
        elseif strcmp(choice, 'No')
            return; % Do nothing, just return to the GUI
        elseif strcmp(choice, 'Exit')
            disp('Exiting without saving...');
            setappdata(hFig, 'ResumeWait', true); % Set flag to true
            uiresume(hFig); % Ensure the UI wait loop is exited properly
        else
            % This should not be reached, but it's here for completeness
            setappdata(hFig, 'ResumeWait', true); % Set flag to true
            uiresume(hFig); % Resume the execution if closed without completing
            delete(hFig); % Close the figure       
        end
    end

    function addROICallback(~, ~)
        validName = false;
        while ~validName
            roiName = inputdlg('Enter the name for the new ROI:', 'New ROI');
            if isempty(roiName)
                return;
            end
            roiName = roiName{1};
            if isvarname(roiName) && ~isfield(hROIs, roiName)
                validName = true;
            else
                errordlg('Invalid or duplicate ROI name. Please enter a valid unique name.', 'Invalid Input');
            end
        end
        roiNames = get(hROIList, 'String');
        set(hROIList, 'String', [roiNames; {roiName}]);
        set(hROIList, 'Value', length(roiNames) + 1); % Select the newly added ROI
        
        createROI([]); % Since it's a new ROI, we don't have default width/height
        hROIs.(roiName) = hROI;
        disp('New ROI added.');
        drawnow;
    end

    function createROI(defaultWH, position)
        % Adjusted to accept default width and height per ROI
        if nargin < 1 || isempty(defaultWH)
            defaultWH = [];
        end

        if nargin < 2
            position = [];
        end

        try
            disp('Creating new ROI...');
            colors = lines(length(get(hROIList, 'String')));    % Generate distinct colors using the 'lines' colormap
            selectedROIName = getSelectedROIName();             % Get the name of the current ROI

            % Get the color for the current ROI based on its position in the list
            currentROIIndex = find(strcmp(get(hROIList, 'String'), selectedROIName));
            color = colors(currentROIIndex, :);

            if isempty(position)
                if isempty(defaultWH)
                    % No default size, no position: let user draw freely
                    hROI = drawrectangle('Parent', hAx, 'Color', color, 'Label', selectedROIName, 'LabelVisible', 'hover');
                else
                    % Use default width and height
                    width = defaultWH(1);
                    height = defaultWH(2);
                    xCenter = (frameWidth - width) / 2;
                    yCenter = (frameHeight - height) / 2;
                    hROI = drawrectangle('Position', [xCenter, yCenter, width, height], 'Parent', hAx, 'Color', color, 'Label', selectedROIName, 'LabelVisible', 'hover');
                end
            else
                % If position is provided, use it
                hROI = drawrectangle('Position', position, 'Parent', hAx, 'Color', color, 'Label', selectedROIName, 'LabelVisible', 'hover');
            end

            % Update the area and dimensions in the GUI
            updateArea(hROI, hAreaText);
            set(hWidthInput, 'String', num2str(hROI.Position(3)));
            set(hHeightInput, 'String', num2str(hROI.Position(4)));

            addlistener(hROI, 'MovingROI', @(src, event) updateArea(src, hAreaText));
            addlistener(hROI, 'ROIMoved', @(src, event) updateArea(src, hAreaText));
            addlistener(hROI, 'ROIMoved', @(src, event) updateLabelPosition(src, selectedROIName)); % Update label position when ROI is moved
            drawnow;
        catch ME
            disp('Error creating ROI:');
            disp(ME.message);
        end
    end

    function updateLabelPosition(src, label)
        % This function updates the label position as the ROI is moved
        src.Label = label; % Keep the label text consistent
    end

    function deleteROICallback(~, ~)
        selectedROIName = getSelectedROIName();
        if isempty(selectedROIName)
            return;
        end
        
        if isfield(hROIs, selectedROIName) && ~isempty(hROIs.(selectedROIName)) && isvalid(hROIs.(selectedROIName))
            delete(hROIs.(selectedROIName)); % Delete the existing ROI
            hROIs = rmfield(hROIs, selectedROIName); % Remove the ROI from the struct
            roiNames = get(hROIList, 'String');
            roiNames(strcmp(roiNames, selectedROIName)) = []; % Remove the name from the list
            set(hROIList, 'String', roiNames);
            % Update listbox selection
            if isempty(roiNames)
                set(hROIList, 'Value', 1);
            else
                set(hROIList, 'Value', max(1, min(get(hROIList, 'Value'), length(roiNames))));
            end
            drawnow;
        end
    end

    function updateArea(src, hAreaText)
        pos = src.Position;
        area = pos(3) * pos(4);
        hAreaText.String = sprintf('Area: %.2f', area);
        set(hWidthInput, 'String', num2str(pos(3)));
        set(hHeightInput, 'String', num2str(pos(4)));
        drawnow;
    end

    function updateROI(~, ~)
        selectedROI = getSelectedROI();
        if ~isempty(selectedROI) && isvalid(selectedROI)
            newWidth = str2double(get(hWidthInput, 'String'));
            newHeight = str2double(get(hHeightInput, 'String'));
            if ~isnan(newWidth) && newWidth > 0 && ~isnan(newHeight) && newHeight > 0
                pos = selectedROI.Position;
                selectedROI.Position = [pos(1), pos(2), newWidth, newHeight];
                updateArea(selectedROI, hAreaText);
                drawnow;
            else
                errordlg('Invalid width or height value. Please enter positive numbers.', 'Invalid Input');
            end
        end
    end

    function selectROI(~, ~)
        % When Click on the list box
        selectedROIName = getSelectedROIName();
        if isempty(selectedROIName)
            return;
        end
        
        if isfield(hROIs, selectedROIName) && ~isempty(hROIs.(selectedROIName)) && isa(hROIs.(selectedROIName), 'matlab.graphics.primitive.Rectangle') && isvalid(hROIs.(selectedROIName))
            selectedROI = hROIs.(selectedROIName);
            set(hWidthInput, 'String', num2str(selectedROI.Position(3)));
            set(hHeightInput, 'String', num2str(selectedROI.Position(4)));
            updateArea(selectedROI, hAreaText);
            drawnow;
        end
    end

    function selectedROIName = getSelectedROIName()
        roiNames = get(hROIList, 'String');
        if isempty(roiNames)
            selectedROIName = '';
            return;
        end
        selectedIndex = get(hROIList, 'Value');
        if isempty(selectedIndex) || selectedIndex > length(roiNames)
            selectedROIName = '';
        else
            selectedROIName = roiNames{selectedIndex};
        end
    end

    function selectedROI = getSelectedROI()
        selectedROIName = getSelectedROIName();
        if isempty(selectedROIName)
            selectedROI = [];
        else
            selectedROI = hROIs.(selectedROIName);
        end
    end
end
