function concatenateFFMPeg(fullFilePaths)
% concatenateVideos: Concatenates multiple video files into one video for one video

if isempty(fullFilePaths)
    filePathObj = fileList.pullFilesUserInput('.mp4');      % Pull videos
    outputFile = makeOutputFileList (filePathObj(1),"originalFolder",{'_Concatenated'});
end  

vdPath = filePathObj(1).fileName;
[folder,~,~] = fileparts(vdPath);
listFileName = fullfile(folder,'ffmpeg_video_list.txt');
fid = fopen(listFileName, 'w');

for i = 1:numel(filePathObj)      
    vdPath = filePathObj(i).fileName;
    fprintf(fid, 'file ''%s''\n', strrep(vdPath, '''', ''''''));
end
fclose(fid);

ffmpegCmd = sprintf('ffmpeg -y -f concat -safe 0 -i "%s" -c copy "%s"', ...
                    listFileName, outputFile{:});

% Execute the FFmpeg command
[status, cmdout] = system(ffmpegCmd);
disp(cmdout);
    
if status ~= 0
    error('FFmpeg error: %s', cmdout);
else
    disp(['Video concatenation completed successfully:', outputFile]);
end

% Clean up: remove the temporary list file
try
    delete(listFileName);
catch ME
    warning('Failed to delete the file: %s. Reason: %s', listFileName, ME.message);
end
end


