function ApplyVideoAdjust_MATLAB(fullFilePaths)
% Code for adjusting gamma factor, brightness, contrast of videos using MATLAB; NOT for many or large videos;
% Call GUI_VideoAdjustMATLAB.m function
% Samme Xie, Jaeger Lab, 7/9/2024    

%% Index all the files for processing
if isempty(fullFilePaths)
    fullFilePaths = fileList.pullFilesUserInput('.mp4');      % Pull videos
    fullFilePaths = convertFileToCell (fullFilePaths);
end          

choice = questdlg('Choose methods to apply video adjustments?', ...
'Choose Method','Read Parameter file','Interactive Adjustment with MATLAB', 'Read Parameter file');

%% Obtain all the parameters for each video
switch choice                       
    case 'Interactive Adjustment with MATLAB'           %%%%%% Choice 1: MATLAB GUI
        for i = 1:numel(fullFilePaths)
            vdpath = fullFilePaths{i};
            [~,name,~] = fileparts(vdpath);
            fprintf('Start selecting Video Adjustment parameters for video: %s \n', name);
            [gamma, brightness, contrast, gain] = GUI_VideoAdjustMATLAB(vdpath); % use GUI to determine parameters   
            paramsStruct.(name) = struct('FileLocation', vdpath, 'Gamma', gamma, 'Brightness', brightness, ...
                              'Contrast', contrast, 'Gain', gain);
        end
    case 'Read Parameter file'                          %%%%%% Choice 2: Read existing parameter file
        [file, path] = uigetfile('*.mat', 'Select Parameters File');
        if isequal(file, 0)
            disp('User canceled file selection');
            return;
        else
            load(fullfile(path,file),'paramsStruct');                     
        end            
    otherwise
        error('Invalid choice.');
end

%% Apply video adjustment to each video
outputFolder = uigetdir(pwd, 'Select a directory to save adjusted videos');

for i = 1:numel(fullFilePaths)
    vdpath = fullFilePaths{i};                       
    disp(['Start to process video: ' vdpath]);
    [~,name,~] = fileparts(vdpath);
    outpath = fullfile(outputFolder,['VideoAdjusted_',name]);
     
    parameters = [paramsStruct.(name).Gamma, paramsStruct.(name).Brightness, paramsStruct.(name).Contrast,... 
        paramsStruct.(name).Gain];  
    if parameters (1) == 1 && parameters (2) == 0 && parameters (3) == 1 && parameters (4) == 1
        continue;
    end
    tic;
    applyVideoAdjustMATLAB(vdpath, outpath, parameters);
    elapsedTime = toc;
    fprintf('Elapsed time: %.2f seconds\n', elapsedTime);
end
end

%% Function to apply adjustments to every frame of a video
function applyVideoAdjustMATLAB(videoPath, outputVideoPath, params)
    inputVideo = VideoReader(videoPath);
    outputVideo = VideoWriter(outputVideoPath,"MPEG-4");
    outputVideo.FrameRate = inputVideo.FrameRate;
    open(outputVideo);

    % Calculate total number of frames
    totalFrames = round(inputVideo.Duration * inputVideo.FrameRate);
    frameCount = 0;
    lastProgress = 0;

    % Check if GPU is available
    gpuAvailable = canUseGPU();
    batchSize  = 10;    
    while hasFrame(inputVideo)
        % Initialize variables for batch processing
        numFramesRead = 0;
        batchFrames = zeros(inputVideo.Height, inputVideo.Width, 3, batchSize, 'double');

        % Read frames into batchFrames
        for i = 1:batchSize
            if hasFrame(inputVideo)
                frame = im2double(readFrame(inputVideo)); % Read and convert frame to double precision
                batchFrames(:,:,:,i) = frame; % Store in batch buffer
                numFramesRead = numFramesRead + 1;
                frameCount = frameCount + 1;
            else
                break;
            end
        end

        % Adjust frames in the batch
        if gpuAvailable
            % Move batch to GPU
            batchFramesGPU = gpuArray(batchFrames(:,:,:,1:numFramesRead));
            adjustedBatchGPU = adjustFrame(batchFramesGPU, params); % Adjust batch on GPU
            adjustedBatch = gather(adjustedBatchGPU); % Move adjusted batch back to CPU
        else
            adjustedBatch = adjustFrame(batchFrames(:,:,:,1:numFramesRead), params); % Adjust batch on CPU
        end

        for i = 1:numFramesRead % write frame
            writeVideo(outputVideo, adjustedBatch(:,:,:,i));
        end

        % Update progress
        currentProgress = floor((frameCount / totalFrames) * 100);

        % Display progress every 10%
        if currentProgress - lastProgress >= 10
            fprintf('Processed %d%% of frames (%d out of %d frames)\n', currentProgress, frameCount, totalFrames);
            lastProgress = currentProgress;
        end
    end

    close(outputVideo);
    disp(['Video processing completed. Saved to: ' outputVideoPath]);    %% Nested: Frame adjustment using GPU for each frame
    
    function adjustedFrame = adjustFrame(frames, params)
        gamma = params(1); % default = 1
        brightness = params(2); % default = 0
        contrast = params(3); % default = 1
        gain = params(4);  % default = 1

        adjustedFrame = frames .^ gamma;
        adjustedFrame = adjustedFrame + brightness;
        adjustedFrame = (adjustedFrame - 0.5) * contrast + 0.5;
        adjustedFrame = adjustedFrame * gain;
        adjustedFrame = min(max(adjustedFrame, 0), 1); % Clip values to [0, 1]
    end

end


