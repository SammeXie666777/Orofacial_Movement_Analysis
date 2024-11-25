function correctFrameRate(inputVideoPath, outputVideoPath, desiredFrameRate)
    % Read the existing video file
    inputVideo = VideoReader(inputVideoPath);
    
    % Create a new video writer object with the desired frame rate
    outputVideo = VideoWriter(outputVideoPath, 'MPEG-4');
    outputVideo.FrameRate = desiredFrameRate;
    open(outputVideo);
    
    % Read and write each frame
    while hasFrame(inputVideo)
        frame = readFrame(inputVideo);
        writeVideo(outputVideo, frame);
    end
    
    % Close the output video file
    close(outputVideo);
    
    fprintf('Video saved with the correct frame rate of %.2f frames per second\n', desiredFrameRate);
end
