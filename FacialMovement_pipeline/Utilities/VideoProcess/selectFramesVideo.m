function frameID = selectFramesVideo(videopath, frameID,method)
%%%%% Select frames from one video
%%% frameID = [array of frame ID] or [](empty: select a duration)
%%% videopath/outpath = 'string' or [] (empty: select from folder)
%%% method = 'MATLAB' or 'FFMPEG' or []

    if isempty(videopath)
        [fileNames, filePath] = uigetfile('*.mp4', 'Select video', 'MultiSelect', 'off');
        videopath = fullfile(filePath, fileNames);
    end
    
    if isempty(frameID) % If empty: first few frames upon user's input
        prompt = {'Start frame ID:','End frame ID'};
        answer = inputdlg(prompt, 'Select first n frames from a video', [1 35], {'0','100'});
        startFrame = str2double(answer{1});
        endFrame = str2double(answer{2});
        frameID = startFrame: endFrame;
    end

    
    if isempty(method)
        method = questdlg('Choose processing method', 'Processing Method', 'MATLAB', 'FFMPEG', 'MATLAB');
    end
    
    tic;
    if strcmp(method, 'MATLAB')
        [dir,name,ext] = fileparts(videopath);
        outpath = fullfile(dir,[name,'_extractframes',ext]);
        videoReader = VideoReader(videopath);
        videoWriter = VideoWriter(outpath, 'MPEG-4');
        videoWriter.FrameRate = videoReader.FrameRate; % Ensure the frame rate is the same
        open(videoWriter);
        
        for i = 1:length(frameID)
            videoReader.CurrentTime = (frameID(i) - 1) / videoReader.FrameRate;
            frame = readFrame(videoReader);
            writeVideo(videoWriter, frame);
        end       
        close(videoWriter);
        
    elseif strcmp(method, 'FFMPEG')
        tempDir = fullfile(tempdir, 'temp_frames');
        if ~exist(tempDir, 'dir')
            mkdir(tempDir);
        end
        
        % Extract frames using ffmpeg
        videoInfo = VideoReader(videopath); % Re-read video info for frame rate
        for i = 1:length(frameID)
            frameFilename = fullfile(tempDir, sprintf('frame_%05d.png', i));
            cmd = sprintf('ffmpeg -i "%s" -vf "select=eq(n\\,%d)" -vframes 1 "%s"', videopath, frameID(i) - 1, frameFilename);
            system(cmd);
        end
        
        % Combine frames into a video
        cmd = sprintf('ffmpeg -framerate %d -i "%s/frame_%%05d.png" -c:v libx264 -pix_fmt yuv420p "%s"', videoInfo.FrameRate, tempDir, outpath);
        system(cmd);
            
        rmdir(tempDir, 's');
    else
        error('Invalid processing method selected.');
    end

    time = toc;
    disp(fprintf(['Video frames extracted and wrote at: ' videopath ' Elapsed time =  %2d'],time));
end
