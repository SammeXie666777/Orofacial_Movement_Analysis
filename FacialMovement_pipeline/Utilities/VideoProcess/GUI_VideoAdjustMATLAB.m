function [gamma, brightness, contrast, gain] = GUI_VideoAdjustMATLAB(videoPath)
    % Read a single video
    if isempty(videoPath) 
        filePathObj = fileList.pullFilesUserInput('.mp4','off');
        videoPath = filePathObj.fileName;
    end
    video = VideoReader(videoPath);
    
    % Extract 30 random frames
    totalFrames = round(video.FrameRate * video.Duration);
    numFrames = 20;
    frameIndices = sort(randperm(totalFrames,numFrames));
    %frameIndices = sort(rand(sample(totalFrames, numFrames)));
    frames = cell(1, numFrames);
    for k = 1:numFrames
        video.CurrentTime = (frameIndices(k) - 1) / video.FrameRate;
        frames{k} = im2double(readFrame(video));
    end

    fprintf('%d Frames extracted randomly from the video\n', numFrames);
    
    % Determine the aspect ratio of the image for axis
    [height, width, ~] = size(frames{1});
    aspectRatio = width / height;
    axesWidth = 800;
    axesHeight = axesWidth / aspectRatio;    
    
    % Create a figure window
    fig = uifigure('Name', 'Interactive Video Adjustment', 'Position', [100, 100, 1200, 800]);
    ax = uiaxes(fig, 'Position', [250, 200, axesWidth, axesHeight]);

    % Display the first frame initially
    imshow(frames{1}, 'Parent', ax);
    
    % Initialize parameters and images
    Para = initializePara();
    gamma = Para(1); % Baseline values (NOT the original values)
    brightness = Para(2);
    contrast = Para(3);
    gain = Para(4);
    originalImg = frames{1};
    adjustedImg = frames{1};
    
    % Flag to track whether playback slider is being updated
    isUpdatingPlaybackSlider = false;
    
    % SLIDER and LABELS for gamma, brightness, contrast, and gain
    gammaLabel = uilabel(fig, 'Position', [250, 160, 100, 22], 'Text', 'Gamma:');
    gammaSlider = uislider(fig, 'Position', [350, 160, 500, 3], 'Limits', [0.1 3.0], 'Value', gamma, ...
        'ValueChangedFcn', @(src, event) updateParameters());
    
    brightnessLabel = uilabel(fig, 'Position', [250, 120, 100, 22], 'Text', 'Brightness:');
    brightnessSlider = uislider(fig, 'Position', [350, 120, 500, 3], 'Limits', [-1.0 1.0], 'Value', brightness, ...
        'ValueChangedFcn', @(src, event) updateParameters());
    
    contrastLabel = uilabel(fig, 'Position', [250, 80, 100, 22], 'Text', 'Contrast:');
    contrastSlider = uislider(fig, 'Position', [350, 80, 500, 3], 'Limits', [0.1 3.0], 'Value', contrast, ...
        'ValueChangedFcn', @(src, event) updateParameters());
    
    gainLabel = uilabel(fig, 'Position', [250, 40, 100, 22], 'Text', 'Gain:');
    gainSlider = uislider(fig, 'Position', [350, 40, 500, 3], 'Limits', [0.1 3.0], 'Value', gain, ...
        'ValueChangedFcn', @(src, event) updateParameters());

    % Create buttons
    resetButton = uibutton(fig, 'Position', [20, 260, 100, 30], 'Text', 'Reset', ...
        'ButtonPushedFcn', @(resetButton, event) resetAdjustments());

    saveButton = uibutton(fig, 'Position', [20, 220, 100, 30], 'Text', 'Save Frame', ...
        'ButtonPushedFcn', @(saveButton, event) saveAdjustedFrame());

    confirmButton = uibutton(fig, 'Position', [20, 180, 100, 30], 'Text', 'Confirm & Close', ...
        'ButtonPushedFcn', @(confirmButton, event) confirmAndClose());
    
    % Playback slider and button
    playbackSlider = uislider(fig, 'Position', [250, 210, 800, 3], 'Limits', [1 numFrames], 'Value', 1, ...
        'ValueChangedFcn', @(src, event) updateVideoPosition());

    playPauseButton = uibutton(fig, 'Position', [1060, 170, 100, 30], 'Text', 'Pause', ...
        'ButtonPushedFcn', @(btn, event) togglePlayPause());

    % Timer to update the video frames with a slower frame rate
    slowFrameRate = 2 * (1 / video.FrameRate); % Adjust this factor as needed
    t = timer('TimerFcn', @(~, ~) updateFrame(round(playbackSlider.Value)), 'Period', slowFrameRate, 'ExecutionMode', 'fixedRate');
    
    start(t); % Start timer
    
    uiwait(fig); % close 
    
    % Cleanup
    stop(t); delete(t); close(fig);

    %%%%%%%% Nested functions
    function Para = initializePara()
        Para = [1, 0, 1, 1]; % [gamma, brightness, contrast, gain]
    end

    function updateParameters()
        gamma = gammaSlider.Value;
        brightness = brightnessSlider.Value;
        contrast = contrastSlider.Value;
        gain = gainSlider.Value;
        frameIdx = round(playbackSlider.Value); % Get the current frame index
        updateFrame(frameIdx); % Apply the changes to the current frame
    end


    function updateFrame(frameIdx)
        if ~isUpdatingPlaybackSlider
            if frameIdx <= numFrames
                frame = frames{frameIdx};
                
                adjustedFrame = adjustFrameMatlab(frame, [gamma, brightness, contrast, gain]);
                
                imshow(adjustedFrame, 'Parent', ax);
                
                % Update the playback slider position, ensuring it stays within limits
                if frameIdx < numFrames && strcmp(playPauseButton.Text, 'Pause')
                    playbackSlider.Value = frameIdx + 1;
                elseif frameIdx >= numFrames
                    playbackSlider.Value = 1; % Restart the playback when it reaches the end
                else
                    playbackSlider.Value = frameIdx;
                end
            end
        end
    end


    function updateVideoPosition()
        isUpdatingPlaybackSlider = true;
        frameIdx = round(playbackSlider.Value);
        if frameIdx <= numFrames
            frame = frames{frameIdx};
            
            % Apply adjustments and display
            adjustedFrame = adjustFrameMatlab(frame, [gamma, brightness, contrast, gain]);
            imshow(adjustedFrame, 'Parent', ax);
        end
        isUpdatingPlaybackSlider = false;
    end

    function togglePlayPause()
        if strcmp(playPauseButton.Text, 'Pause')
            stop(t);
            playPauseButton.Text = 'Play';
        else
            if playbackSlider.Value >= numFrames
                playbackSlider.Value = 1; % Restart from the beginning
            end
            start(t);
            playPauseButton.Text = 'Pause';
        end
    end

    function resetAdjustments()
        % Reset the sliders to their initial values
        Para2 = initializePara();
        gammaSlider.Value = Para2(1);
        brightnessSlider.Value = Para2(2);
        contrastSlider.Value = Para2(3);
        gainSlider.Value = Para2(4);
        
        % Reset parameters
        gamma = Para2(1);
        brightness = Para2(2);
        contrast = Para2(3);
        gain = Para2(4);
    
        % Apply reset adjustments to all frames
        for k = 1:numFrames
            frames{k} = imadjust(frames{k}, [], [], gamma);
            frames{k} = frames{k} + brightness;
            frames{k} = (frames{k} - 0.5) * contrast + 0.5;
            frames{k} = frames{k} * gain;
            frames{k} = min(max(frames{k}, 0), 1); % Clip values to [0, 1]
        end
    
        adjustedImg = originalImg; % Reset the adjusted image to the original
    
        % Reset the playback slider to the beginning
        playbackSlider.Value = 1;
    
        % Display the original image
        imshow(originalImg, 'Parent', ax);
    end


    function saveAdjustedFrame()
        stop(t); % Pause the timer to get a specific frame
        
        % Determine the frame to save
        Para3 = initializePara();
        if gammaSlider.Value == Para3(1) && brightnessSlider.Value == Para3(2) && ...
           contrastSlider.Value == Para3(3) && gainSlider.Value == Para3(4)
            frameToSave = originalImg;
        else
            % Get the current frame
            frameIdx = round(playbackSlider.Value);
            frame = frames{frameIdx};
            
            % Apply adjustments
            adjustedFrame = adjustFrameMatlab(frame, [gamma, brightness, contrast, gain]);
            frameToSave = adjustedFrame;
        end
        
        % Ask the user for a filename
        [file, path] = uiputfile('*.jpg', 'Save Adjusted Frame As');
        if ischar(file)
            % Save the frame
            imwrite(frameToSave, fullfile(path, file));
            disp(['Frame saved as ', fullfile(path, file)]);
        end
        
        % Resume the timer if the video was playing
        if strcmp(playPauseButton.Text, 'Pause')
            start(t);
        end
    end

    function confirmAndClose()
        % Get the values from the sliders before closing
        gamma = gammaSlider.Value;
        brightness = brightnessSlider.Value;
        contrast = contrastSlider.Value;
        gain = gainSlider.Value;

        % Close the figure window and resume execution
        uiresume(fig);
        disp(['Gamma: ', num2str(gamma)]);
        disp(['Brightness: ', num2str(brightness)]);
        disp(['Contrast: ', num2str(contrast)]);
        disp(['Gain: ', num2str(gain)]);

        % Save parameters to a text file
        [dir,name,~] = fileparts(videoPath);
        paramsFilePath = fullfile(dir, 'MATLAB_AdjustParameter.txt');
        fileID = fopen(paramsFilePath, 'w');
        if fileID == -1
            error('Error opening the file: %s', paramsFilePath);
        end
        fprintf(fileID, 'File location: %s\nGamma: %f\nBrightness: %f\nContrast: %f\nGain: %f\n', ...
                videoPath, gamma, brightness, contrast, gain);
        fclose(fileID);
    
        % Create a structure to store the parameters
        structFilePath = fullfile(dir, 'MATLAB_AdjustParameter.mat');
        if exist(structFilePath,"file")
            load(structFilePath,'paramsStruct');
        end    
        paramsStruct.(name) = struct('FileLocation', videoPath, 'Gamma', gamma, 'Brightness', brightness, ...
                              'Contrast', contrast, 'Gain', gain);
        save(structFilePath, 'paramsStruct');
        disp(['Parameters saved as a text file and mat structure @ ', structFilePath]);
    end

    % Image adjust function: Adjust image use built-in function imageadj (GreyScale)
    %% Frame adjustment function
    function adjustedFrame = adjustFrameMatlab(frame, params)
        gamma = params(1); % default = 1
        brightness = params(2); % default = 0
        contrast = params(3); % default = 1
        gain = params(4);  % default = 1
        
        % Apply adjustments
        %adjustedFrame = imadjust(frame, [], [], gamma);
        adjustedFrame = frame .^ gamma;
        adjustedFrame = adjustedFrame + brightness;
        adjustedFrame = (adjustedFrame - 0.5) * contrast + 0.5;
        adjustedFrame = adjustedFrame * gain;
        adjustedFrame = min(max(adjustedFrame, 0), 1); % Clip values to [0, 1]

    end

end