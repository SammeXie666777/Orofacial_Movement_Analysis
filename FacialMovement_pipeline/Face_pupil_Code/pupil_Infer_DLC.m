function [Output,RawData] = pupil_Infer_DLC(matList,methods,p_threshold,plot_on)
% Pupil estimation and preprocessing function
% Samme Xie, Jaeger Lab, 08/24/2024
%   matList: list of mat files containing keypoints as x,y,p
%   methods: fit_circle or medDist
%   p_threshold: 
%   plot_on: 1 or other 

% Some preprocessing steps: 
% 1) pupil point < p_threshold poiont: nan
% 2) Take first derivative: examine jumps and cut-off based on jump
% 3) Lid-distance < min_lid: nan
% 4) Interpolate among small gaps; leave NaN for large gaps
% 5) Filter

% Output:
% Smoothed trace should only contains NaN and non-zero values
%% Input: fileName 
if isempty(matList)
    configpath = '/Users/samme/Library/CloudStorage/OneDrive-Emory/Matlab/Orofacial_movement/DLC Model/Pupil/Pupil_0724_newModel/FaceMovement_Pupil-SammeXie-2024-07-25';
    configpath = fileList.translatePath({configpath});
    objList = fileList.pullFilesUserInput(".h5");
    h5file = convertFileToCell (objList);
    matList = DLC_h5_to_Mat (h5file,configpath{:},'file');
end

[~,vdname,~] = fileList.renameFileNames(matList,0); % used for field names
Output = struct; RawData = struct;

%%
% For each matfile
for i = 1:numel(matList)
    %% orgnize data: Miao's code
    load(matList{i}, "markerpos");
    labelNames = fieldnames(markerpos);
    if i == 1
        fprintf('Marker names are: %s \n', strjoin(labelNames));
    end
    fprintf('Start to process video: %s. \n', vdname{i});

    pupil_labels = find(contains(labelNames, 'pupil'));
    eyelid_labels = find(contains(labelNames, 'eyelid'));
    
    % Initialize the pupil and eyelid structs with empty fields
    pupil = struct('xy', [], 'p', []);
    eyelid = struct('xy', [], 'p', []);
    center = struct('xy', [], 'p', []);
    
    all_labels = [pupil_labels; eyelid_labels]; % Combine all labels into one array    
    for currLabel = all_labels'
        curreL = labelNames{currLabel};
        if ismember(currLabel, pupil_labels)&& ~contains(curreL, '_center')
            pupil.xy = [pupil.xy; [markerpos.(curreL).x; markerpos.(curreL).y]]; % x y vertically concatenated
            pupil.p = [pupil.p; markerpos.(curreL).p];
        elseif contains(curreL, '_center')
            center.xy = [markerpos.(curreL).x; markerpos.(curreL).y];
            center.p = markerpos.(curreL).p;
        elseif ismember(currLabel, eyelid_labels)
            eyelid.xy = [eyelid.xy; [markerpos.(curreL).x; markerpos.(curreL).y]];
            eyelid.p = [eyelid.p; markerpos.(curreL).p];
        end
    end
    
    RawData.(vdname{i}) = struct('pupil', pupil, 'eyelid', eyelid,'pupil_center',center);
    
    %% 
    % Fit circle: need > 3 pts with above p_thres to have a value
    % methods: 
    [centers, Rs, lid_dist, ~] =  fit2shape(RawData.(vdname{i}), p_threshold, methods);
    
    % Blinking frames stored as nan
    min_dist = 40; 
    blink_idx = lid_dist < min_dist & ~isnan(lid_dist);    
    Rs (blink_idx) = nan;     
    fprintf ('The number of frames of blinking detected is %d \n', sum (blink_idx));
    %% Interpoloate and smooth: only blinking frames got nan; other low-confidence points interpolated
    wd = 5;
    nonNanIdx = ~isnan(Rs);
    if strcmp (methods, 'fit_cricle')
        interpo_Rs = interp1(find(nonNanIdx), Rs(nonNanIdx), 1:numel(Rs), 'linear','extrap'); 
        maxGap = 70; % deal with large s ndices, false]);
        % position > maxgap number of consecutive nan: linear interpolation
        startIndices = find(gapTransitions == 1); % Start and end indices of NaN sequences
        endIndices = find(gapTransitions == -1) - 1;
        gapSizes = endIndices - startIndices + 1;
        largeGapIdx = find(gapSizes > maxGap);
        largeGaps = arrayfun(@(s, e) s:e, startIndices(largeGapIdx), endIndices(largeGapIdx), 'UniformOutput', false);
        largeGaps = [largeGaps{:}];
        smoothed_Rs = medfilt1(interpo_Rs, wd, 'omitnan', 'truncate'); % smooth
        smoothed_Rs(largeGaps) = NaN;
    else
        interpo_Rs = Rs;
        interpo = interp1 (find(nonNanIdx), Rs(nonNanIdx),find(~nonNanIdx),'pchip');
        interpo_Rs (~nonNanIdx) = interpo;
        smoothed_Rs = medfilt1(interpo_Rs, wd, 'omitnan', 'truncate'); % smooth
    end

    smoothed_Rs(blink_idx) = NaN; % make blinking nan

    %%
    if plot_on == 1
        frame = 1:1200;
        plot(Rs(frame)); % Plot all data
        hold on
        plot(smoothed_Rs(frame));
        legend('Rs','Rs_Smoothed');
        pause (2);
        saveas(gcf,[vdname{i} '_fisrt1200frames'],'fig');
        delete (gcf);
        
        % Align video with traces
        [direc,~,~] = fileparts(matList{i});
        cd(direc); 
        allvd = dir('*.mp4');
        idx =  cellfun(@(x) contains(x, vdname{i}) && contains(x, '_labeled') && ~contains (x, '_pupilaligned') && ~contains (x, 'extractframes'), {allvd.name});         
        movieObj = VideoReader(allvd(idx).name);
        [~,name,ext] = fileparts(allvd(idx).name);

        alltrace = [Rs(frame);smoothed_Rs(frame)];
        orofacial_mouse.displayMotion(movieObj, [name,'_pupilaligned',ext], [], alltrace, frame(1), 1:length(frame),[]);
        selectFramesVideo(allvd(idx).name, find(blink_idx),'MATLAB'); % Save video to check blinking
    end
    
    Output.(vdname{i}).RawTrace = Rs;
    Output.(vdname{i}).FilteredTrace = smoothed_Rs;
    Output.(vdname{i}).PupilCenter = centers;
    Output.(vdname{i}).LidDistance = lid_dist;
    Output.(vdname{i}).BlinkThresDist = min_dist;

end

end

%% Subfunctions
%% ------------------------- Fit circle: From Miao:  pupil_Step4_extract_DLC_pupil_trace
function [center, r] = fit_circle(x, y)
% function from https://www.mathworks.com/matlabcentral/fileexchange/5557-circle-fit
% Need >= 3 points to define a circle
    x = x(:);
    y = y(:);
    a=[x y ones(size(x))]\(-(x.^2+y.^2));
    center.x = -.5*a(1);
    center.y = -.5*a(2);
    r  =  sqrt((a(1)^2+a(2)^2)/4-a(3));
end

% Fit circle or median distance
function [centers, Rs, lid_dist, pupil_label_positions] =  fit2shape(labels, p_threshold, methods)
%%
    numFrames = size(labels.pupil.xy, 2);
    pupil_label_positions = cell(1, numFrames);
    centers =  nan(2,numFrames);   %struct('x', cell(1, numFrames));
    Rs = nan(1, numFrames);
    lid_dist = nan(1, numFrames);
    
    for currFrame = 1:numFrames
        % Threshold with p_thres
        pupil_xys = labels.pupil.xy(:,currFrame);
        pupil_xys = [pupil_xys(1:2:end), pupil_xys(2:2:end)]; % reshape to make 8-by-2 matrix
        idx =  labels.pupil.p(:,currFrame) <= p_threshold;
        pupil_xys(idx,:) = []; 
        
        % calculate distance of the center of eyelids pn;y p > threshold
        eyelid_xys = labels.eyelid.xy(:,currFrame); % all eyelid points are labeled
        eyelid_xys = [eyelid_xys(1:2:end), eyelid_xys(2:2:end)];
        if labels.eyelid.p (1,currFrame) >= p_threshold || labels.eyelid.p (5,currFrame)  >= p_threshold
            lid_dist(1, currFrame) = pdist([eyelid_xys(1,:); eyelid_xys(5,:)], 'euclidean'); % the 1st and 5th point to calc dist
        end
        
        % Calculate pupil: 2 methods
        if strcmp (methods, 'fit_circle')  % Seems to gretaly exaggerate radius; result in much greater 
            % Fit a circle >= 3 above p-thres points
            if size(pupil_xys, 1) >= 3 && (~isnan(pupil_xys(1, 1)))
                [center, r] = fit_circle(pupil_xys(:,1), pupil_xys(:,2)); % fit_circle (x,y)
                centers(:,currFrame) = [center.x; center.y];
                Rs(1, currFrame) = r * 2;            
            end
        else
            % Find median values from all points
            if labels.pupil_center.p(currFrame) > p_threshold
                dlc_cen = labels.pupil_center.xy(:,currFrame);
                dist = sqrt( (pupil_xys(:, 1) - dlc_cen(1)).^2 + (pupil_xys(:, 2) - dlc_cen(2)).^2);
                Rs (1, currFrame) = median (dist);
            end
                        
        end
        
        pupil_label_positions{1, currFrame} = pupil_xys;
    end
    totallidnan =  sum(isnan(lid_dist));
    totalnan = sum(isnan(Rs));
    fprintf("Total frames without enough points for pupil inference = %d and eyelid dist calculation = %d. \n",totalnan,totallidnan);
    
end

