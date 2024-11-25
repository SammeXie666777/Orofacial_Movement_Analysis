function face_stats = MotionEnergyCalculation(vdname, ROI, numFrameTrial, gamma)
% MotionEnergyCalculation computes trial-based motion energy for a video.
%
% Inputs:
%   vdname        - Video file name (string).
%   ROI           - Structure containing 'face' and 'bg' ROI definitions.
%   numFrameTrial - 1-by-nTotalTrials array containing number of frames for each trial.
%   gamma         - Gamma correction factor (scalar).
%
% Output:
%   face_stats    - Structure containing:
%                   - BpodVideoNframeDiff: Difference in frame count between Bpod and video.
%                   - ROI: The ROI definitions used.
%                   - VdPath: The path of the video file.
%                   - gamma: The gamma correction factor used.
%                   - RawTrace: Cell array of raw motion energy per trial.
%                   - FilteredTrace: Cell array of median-filtered motion energy per trial.

%% (OPTIONAL) Select files and get gamma
if isempty(vdname)
    disp('Selecting videos to be analyzed');
    [filename, pathname] = uigetfile('*.mp4', 'Select Video File');
    vdname = fullfile(pathname, filename);
end

if isempty(gamma)
    gamma = input(sprintf("The gamma applied to video: %s is: ", vdname));
elseif gamma == 0 % All gamma values = 1
    gamma = 1; 
end

%% (OPTIONAL) Find ROI(s) if empty 
if isempty(ROI)
    disp('Use GUI to find ROI for video; Needs to define a background ROI and face ROI:');
    ROIWidthHeight = input('Input ROI width and height as [width, height]: ');
    currentROI = GUI_Cropping(vdname, ROIWidthHeight, {'face', 'bg'}, 0);
else
    if all(isfield(ROI, {'face', 'bg'}))        
        currentROI = ROI;
    else
        error('ROI must have fields "face" and "bg".');
    end
end

face_stats.ROI = currentROI;
face_stats.VdPath = vdname;
face_stats.gamma = gamma;

%% Initialize Video Reader
movObj = VideoReader(vdname);
vidHeight = movObj.Height;
vidWidth = movObj.Width;
framerate = movObj.FrameRate;
numFrames = floor(movObj.Duration * framerate); % Use duration to estimate total frames

fprintf('Start processing video: %s.\n', vdname);

% Find difference between Bpod and video frame counts
nTrial = length(numFrameTrial);
cum_trial = cumsum(numFrameTrial);
diffnf = abs(numFrames - cum_trial(end));
fprintf('Difference between video frames and Bpod frames: %d frames\n', diffnf);
face_stats.BpodVideoNframeDiff = diffnf;
if diffnf >= 300 % 3 seconds at 100 Hz
    warning('Video is not aligned with Bpod: motion energy not calculated.');
    return;
end

%% Create ROI Masks
% Convert ROI coordinates to integer indices
roiF = currentROI.face;
roiB = currentROI.bg;
yF = floor(roiF.Y); xF = floor(roiF.X); width_F = floor(roiF.Width); height_F = floor(roiF.Height);
yB = floor(roiB.Y); xB = floor(roiB.X); width_B = floor(roiB.Width); height_B = floor(roiB.Height);

% Create masks outside the loop
mask = zeros(vidHeight, vidWidth);
mask(yF:yF+height_F-1, xF:xF+width_F-1) = 1; % Face ROI
mask(yB:yB+height_B-1, xB:xB+width_B-1) = 2; % Background ROI

% If GPU is available, transfer mask to GPU
gpuAvailable = gpuDeviceCount > 0;
if gpuAvailable
    mask = gpuArray(mask);
end

%% Initialize variables for motion energy
mvmt = cell(1, nTrial);
mvmt_filt = cell(1, nTrial);
%mvmt_zscore = cell(1,nTrial);
%% Process frames sequentially
fprintf('Processing frames sequentially...\n');

% Initialize variables
frameIdx = 0;
trialIdx = 1;
cumFrameCounts = [0, cum_trial];
faceData = [];
bgData = [];
movObj.CurrentTime = 0;

% Start processing frames
while hasFrame(movObj)
    frameIdx = frameIdx + 1;
    thisFrame = readFrame(movObj);
    
    % Check if we need to move to the next trial
    if frameIdx > cumFrameCounts(trialIdx + 1)
        % FME for entire trial
        fc_M = abs(diff(faceData));
        mvmt{trialIdx} = gather (fc_M);
        mvmt_filt{trialIdx} = medfilt1(gather(fc_M),100, 'truncate'); % 
        %mvmt_zscore{trialIdx} =  normalize(mvmt_filt{trialIdx},'range'); % normalize to min-max of the smoothed single trial
        fprintf('Trial %d processed.\n', trialIdx);
        
        % Move to next trial
        trialIdx = trialIdx + 1;
        faceData = [];
        bgData = [];
        
        % Break if all trials are processed
        if trialIdx > nTrial
            break;
        end
    end
    % Process each frame
    if gamma ~= 1
        thisFrame = gammaCorrectionInverse(thisFrame, gamma);
    end    
    [faceVal, bgVal] = motion_bgSubtract(thisFrame, mask);
    faceData = [faceData, faceVal];
    bgData = [bgData, bgVal];
end

% Process the last trial if not already processed
if trialIdx <= nTrial
    fc_M = abs(diff(faceData));
    mvmt{trialIdx} = gather (fc_M); % Store as double array
    mvmt_filt{trialIdx} = medfilt1(gather(fc_M), floor(framerate)/2, 'truncate');
    fprintf('Trial %d processed.\n', trialIdx);
end

%% Save output to face_stats structure
face_stats.RawTrace = mvmt;
face_stats.FilteredTrace = mvmt_filt;

end

%% Subfunctions
% Background subtraction for illumination
function [face, bg] = motion_bgSubtract(thisFrame, mask)
    grayImage = double(rgb2gray(thisFrame)); % Convert frame to grayscale
    if isa(mask, 'gpuArray')
        grayImage = gpuArray(grayImage);
    end
    bg = mean(grayImage(mask == 2), 'all'); 
    facePixels = grayImage(mask == 1) - bg; % Subtract background from face ROI pixels
    face = mean(abs(facePixels), 'all');
end

% Inverse gamma correction
function uncorrectedImage = gammaCorrectionInverse(correctedImage, gamma)
    Rmax = 255; % Maximum pixel value for uint8 format
    uncorrectedImage = Rmax * ((double(correctedImage) / Rmax).^(1 / gamma));
    uncorrectedImage = uint8(uncorrectedImage);
end
