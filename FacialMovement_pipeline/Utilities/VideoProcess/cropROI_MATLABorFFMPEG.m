function ROI = cropROI_MATLABorFFMPEG(MATLABorFFMPEG, CroppingDefualt,ROIname,mouseID)
%   Input: MATLABorFFMPEG = MATLAB or FFMPEG or onlyGetROI
%          CroppingArea = empty or a number of ROI area
%   Need to have valid video file name
%   Samme Xie, Jaeger Lab, 6/23/2024   

%% Get cropping parameters for all videos in the list
vdListObj = fileList.pullFilesUserInput(".mp4","on");          % select files for cropping   % create an output file list 
fileListCell = convertFileToCell (vdListObj);

if ~isempty(mouseID)
    [~,newPaths,vdList] = fileList.renameFileNames(fileListCell,0,{mouseID}); % vdList original PathName
else
    [~,newPaths,vdList] = fileList.renameFileNames(fileListCell,0); % vdList original PathName
end

% Get an ROI structure
%GUIorNot = questdlg('Get new ROI parameters or load ROI parameter mat file; Select NEW ROI if no mat structure file', 'ROI selection', 'New ROI', 'Old Parameters','New ROI');    
choice = questdlg('Do you want to apply the same ROI to every video?', 'ROI application', 'Yes', 'No', 'Yes');    

%if strcmp(GUIorNot, 'New ROI')          %%%%%% Call ROI
if strcmp(choice, 'No')
    for i = 1:numel(vdList) % Store ROI for each video
        [~,name,~] = fileparts(newPaths{i});  
        disp(['The current video for choosing ROI is ', name]);       
        ROI.(name) = GUI_Cropping(vdList{i}, CroppingDefualt,ROIname,0); 
    end
elseif strcmp(choice, 'Yes') % Get one ROI for every video
    [~,name,~] = fileparts(newPaths{1});  
    disp(['Video used to determine ROI is ', name]);       
    ROI.(name) = GUI_Cropping(vdList{1}, CroppingDefualt,ROIname,0); 
else
    disp('selection canceled')
end
   
croppingOrNot = questdlg('Proceed to video cropping or not; Select No if you just want to obtain ROI', 'Cropping?', 'Yes', 'No', 'Yes');    
if strcmp(croppingOrNot, 'Yes')
elseif strcmp(croppingOrNot, 'No')
    disp('No cropping');
    return;
else
    disp('Selection canceled');    
end

%% Process: use ROI struc 
% Can only choose to process one ROI at a time; 
outputFolder = uigetdir(pwd, 'Select a directory to save cropped videos');

disp('Start to process video for cropping');
for i = 1:numel(vdList)
    disp(['The current video being processed is ', vdList{i}]);   
    name = newPaths{i};
    % Select ROI and check if ROI exists
    if strcmp(choice, 'No')
        if isfield(ROI,name) % Check if the video has ROI param file
            if isscalar(fieldnames(ROI.(name)))
                ROIname = fieldnames(ROI.(name)); 
                ROIname = ROIname{:};
            else
                ROIname = selectROI(fieldnames(ROI.(name)));
            end
        else
            error(['No ROI parameter for file: ' name ' Run cropping function first to get ROI or use one ROI for all videoes'])
        end
        currentROI =  ROI.(name).(ROIname);
    elseif strcmp(choice, 'Yes') && i == 1 % Ask for the first video
        temp = fieldnames(ROI);
        exampleVideo = selectROI (temp); % select from Parameter file for example video
        ROIname = selectROI(fieldnames(ROI.(exampleVideo))); 
        currentROI = ROI.(exampleVideo).(ROIname);
    end

    outPutPath = fullfile(outputFolder,[name,'_',ROIname,'.mp4']);    

    switch MATLABorFFMPEG
    case 'MATLAB'
        newROI = cropMATLAB(vdList{i}, outPutPath, currentROI); 
    case 'FFMPEG'
        newROI = cropFFMPEG(vdList{i}, outPutPath, currentROI);
    end 

    matFilePath = fullfile(outputFolder, 'croppingParameters.mat');      
    if exist(matFilePath,'file')
        load(matFilePath);   % Load existing parameters;        
    end  
    croppingParameters.(name).(ROIname) = newROI;
end
save(matFilePath, 'croppingParameters');
end

%%%%%%%% Subfunctions %%%%%%%%%%
%% Cropping and writing video using MATLAB
function ROI = cropMATLAB(vdpath, outputVideoPath, ROI)
    if ~isfile(vdpath)
        error('The specified video file does not exist.');
    end
        
    videoObj = VideoReader(vdpath);
    frameWidth = videoObj.Width;
    frameHeight = videoObj.Height;
    numFrames = floor(videoObj.Duration * videoObj.FrameRate); % Total number of frames

    ROI.Width = floor(ROI.Width);
    ROI.Height = floor(ROI.Height);
    ROI.X = floor(ROI.X);
    ROI.Y = floor(ROI.Y);

    % Ensure ROI is within the frame dimensions
    ROI.Width = min(ROI.Width, frameWidth - ROI.X);
    ROI.Height = min(ROI.Height, frameHeight - ROI.Y);

    outputVideo = VideoWriter(outputVideoPath, 'MPEG-4');
    outputVideo.FrameRate = videoObj.FrameRate;
    open(outputVideo);
    
    frameCount = 0;
    tic;
    while hasFrame(videoObj)
        frame = readFrame(videoObj);
        frameCount = frameCount + 1;
        
        % Ensure cropped frame dimensions are consistent
        croppedFrame = imcrop(frame, [ROI.X, ROI.Y, ROI.Width - 1, ROI.Height - 1]);
        % If the cropped frame is not the expected size, pad it
        if size(croppedFrame, 1) ~= ROI.Height || size(croppedFrame, 2) ~= ROI.Width
            croppedFrame = imresize(croppedFrame, [ROI.Height, ROI.Width]);
        end
        writeVideo(outputVideo, croppedFrame);
        
        % Display progress every 10 frames
        if mod(frameCount, 100) == 0
            fprintf('%d out of %d frames processed\n', frameCount, numFrames);
        end
    end
    close(outputVideo);
    deltT = toc;
    % Save the new info of video in the ROI
    videoObj = VideoReader(outputVideoPath);
    ROI.croppedPara.outputPath = outputVideoPath;
    ROI.croppedPara.Width = videoObj.Width;
    ROI.croppedPara.Height = videoObj.Height;
    ROI.croppedPara.Area = videoObj.Width * videoObj.Height;

    fprintf('Cropped video saved to %s\n', outputVideoPath);
    fprintf('Elapsed time = %2d',deltT);
end


%% Call FFMPEG to batch process
function ROI = cropFFMPEG(vdpath, outpath, ROI)
    cropCmd = sprintf('ffmpeg -y -i "%s" -vf "crop=%d:%d:%d:%d" -c:a copy "%s"', ...
                      vdpath, ROI.Width, ROI.Height, ROI.X, ROI.Y, outpath);
    [status, cmdout] = system(cropCmd);
    if status ~= 0
        error('FFmpeg error: %s', cmdout);
    else
        disp(['Video cropped successfully: ', outpath]);
    end
    videoObj = VideoReader(outpath);
    ROI.croppedPara.outputPath = outpath;
    ROI.croppedPara.Width = videoObj.Width;
    ROI.croppedPara.Height = videoObj.Height;
    ROI.croppedPara.Area = videoObj.Width * videoObj.Height;
    %close(videoObj);
end

%% list selection
function selectedKeyword = selectROI(keywords) % input: cell
[selectedIndex, isOK] = listdlg('PromptString', 'Select a keyword:', ...
                                'SelectionMode', 'single', ...
                                'ListString', keywords);
% Check if the user made a selection
if isOK
    selectedKeyword = keywords{selectedIndex};
    disp(['You selected: ', selectedKeyword]);
else
    disp('No selection made');
end
end
