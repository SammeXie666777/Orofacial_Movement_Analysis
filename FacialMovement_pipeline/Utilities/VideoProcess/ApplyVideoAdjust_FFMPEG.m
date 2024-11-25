function output_parameter = ApplyVideoAdjust_FFMPEG(mouseID, parameters)
% Samme Xie - Jaeger Lab - 06/25/2024
% For this code to run, FFMPEG must be installed according to https://www.wikihow.com/Install-FFmpeg-on-Windows.
% fullFilePaths = [] or input file path cell arrays 
% outpath = [] or output file path
% parameters = for display: [] or [gamma, brightness, contrast, gain]
%              for process: [gamma, brightness, contrast, gain] or structure
% Can be stand-alone function

%% Chose videos for processing
filePathObj = fileList.pullFilesUserInput('.mp4');      % Pull videos
[~,newPaths,fullFilePaths] = renameFileNames(filePathObj,0,{mouseID}); % vdList original PathName
[outpath] = makeOutputFileList (fileObj,fileLocation,mouseID);  % Construct output names only when processing video

%% display and save settings: for every video 
    
% Initialize parameters
if ~isempty(parameters)
    gamma = parameters(1);
    brightness = parameters(2);
    contrast = parameters(3);
    gain = parameters(4); 
else
    brightness = 0;
    gain = 1;
    contrast = 1;
    gamma = 1;
end

for i = 1:numel(fullFilePaths)
    currentVideo = fullFilePaths{i};
    [~, videoName, ~] = fileparts(newPaths{i});        
    output_parameter.(videoName).brightness = brightness;
    output_parameter.(videoName).gain = gain;
    output_parameter.(videoName).contrast = contrast;
    output_parameter.(videoName).gamma = gamma;
    output_parameter.(videoName).FullvideoPath = currentVideo;

    satisfiedornot = true;
    while satisfiedornot                
        % Construct FFMPEG command
        cmd = ['ffplay -i "' currentVideo '" -vf "eq=gamma=' num2str(output_parameter.(videoName).gamma) ...
               ':brightness=' num2str(output_parameter.(videoName).brightness) ':contrast=' num2str(output_parameter.(videoName).contrast) ...
               ',lut=a=val*' num2str(output_parameter.(videoName).gain) '"'];
        status = system(cmd);
        if status ~= 0
            error('Error executing FFMPEG command.');
        end
        
        choice = questdlg('Are you satisfied with the adjustments?', ...
                          'Continue or Quit', ...
                          'Yes', 'No', 'Yes','Exit');          
        % If not satisfied
        if strcmp(choice, 'No')
            prompt = {'Enter brightness (-1.0 to 1.0):', 'Enter gain (0 to 10):', 'Enter contrast (0.0 to 2.0):', 'Enter gamma (0.1 to 10.0):'};
            dims = [1 35];
            definput = {num2str(output_parameter.(videoName).brightness), num2str(output_parameter.(videoName).gain), num2str(output_parameter.(videoName).contrast), num2str(output_parameter.(videoName).gamma)};
            answer = inputdlg(prompt, 'Adjust Video Parameters', dims, definput);   
            output_parameter.(videoName).brightness = str2double(answer{1});
            output_parameter.(videoName).gain = str2double(answer{2});
            output_parameter.(videoName).contrast = str2double(answer{3});
            output_parameter.(videoName).gamma = str2double(answer{4});
        elseif strcmp(choice, 'Yes')
            satisfiedornot = false; % Exit loop if user cancels the dialog
        elseif strcmp(choice, 'Exit')
            exit;
        end
    end
end

% Save the parameter file to a location of user's selection (one mat for all vidoes)
path = uigetdir(pwd, 'Select a directory to save the file'); % Ask user to select where to save param file
filename = [mouseID '_FFMPEG_AdjustParameter.mat'];
if isequal(filename, 0)
    disp('User canceled file save');
    return;
else
    paramsFilePath = fullfile(path, filename);
    if exist(paramsFilePath,"file")
        load(paramsFilePath,'ffmpegAdjustPara');
        fieldNames = fieldnames(output_parameter);
        for i = 1:numel(fieldNames)
            fieldName = fieldNames{i};
            ffmpegAdjustPara.(fieldName) = output_parameter.(fieldName);
        end
    end
end
save(paramsFilePath, 'ffmpegAdjustPara');
disp(['Parameters saved as a mat structure @ ', paramsFilePath]);

%% Process video: parameters can't be empty 
useinput = input ('Do you want to continue for processing using selected parameters. YES = 1, NO = 0');
if isempty(parameters)
parameters = output_parameter;
end

if useinput == 1
    for i = 1:numel(fullFilePaths)
        currentVideo = fullFilePaths{i};
        [~, videoName, ~] = fileparts(newPaths{i});
        outVideo = outpath{i};
        if isstruct(parameters) 
            gamma = parameters.(videoName).gamma;
            brightness = parameters.(videoName).brightness;
            gain = parameters.(videoName).gain;
            contrast = parameters.(videoName).contrast;
            parameters.(videoName).outputPathAfterAdjust = outVideo;
        else
            gamma = parameters(1); brightness = parameters(2); contrast = parameters(3); gain = parameters(4);  
        end
        
        if brightness == 0 && gain == 1 && contrast == 1 && contrast == 1 % if default parameter: skip
            continue;
        end

        cmd = ['ffmpeg -i "' currentVideo '" -vf "eq=gamma=' num2str(gamma) ':brightness=' num2str(brightness) ':contrast=' num2str(contrast) ',lut=a=val*' num2str(gain) '"' ...
            ' -c:v libx264 -crf 18 -preset veryslow -c:a copy "' outVideo '"'];
        status = system(cmd);
    end
    
    % Save used parameters
    if isstruct(parameters) 
        output_parameter = parameters;       
    else
        output_parameter.gamma = gamma; output_parameter.gain = gain; output_parameter.contrast = contrast; output_parameter.brightness = brightness;
        output_parameter.adjustedVideosUsingPara = outpath;
    end
    [filename, path] = uiputfile('*.mat', 'Save Parameters used for video adjustment as a mat File');
    save(fullfile(path, filename), 'output_parameter'); 
    disp('Done. All videos processed')
end
end
