function face_state = restMvmtPeriod(mvmt_filt,fs,plot_fig)
    mvmt_filt_z = zscore(mvmt_filt);
    
    mvmt_thr = 0; %1.5.*std(mvmt_filt_z);
    mvmt_inds = find(mvmt_filt_z>mvmt_thr);
    rest_inds = find(mvmt_filt_z<mvmt_thr);

    %% Find continuous periods of rest and movement
    mvmt_inds01 = zeros(1,length(mvmt_inds));
    mvmt_inds01(mvmt_inds) = 1;
    mvmt_inds01(1) = 0; mvmt_inds01(end) = 0;
    mvmt_pulses = findPulses(mvmt_inds01);

    rest_inds01 = zeros(1,length(rest_inds));
    rest_inds01(rest_inds) = 1;
    rest_inds01(1) = 0; rest_inds01(end) = 0;
    rest_pulses = findPulses(rest_inds01); 

    mvmt_periods = mvmt_pulses.ends-mvmt_pulses.starts;
    rest_periods = rest_pulses.ends-rest_pulses.starts;

    %% Histogram of rest vs movement period lengths
    edges = 1:5:500;
    if plot_fig == 1
        figure() 
        histogram(mvmt_periods,edges), hold on
        histogram(rest_periods,edges)
        title(' Histogram of Rest vs Movement Period Lengths')
        legend ('Movement', 'Rest')
    end
    %% Find periods greater than some time threshold (using 2s)
    min_sec = 1;
    max_sec = 4;
    min_length = min_sec.*fs;
    max_length = max_sec.*fs;
    mvmt_good = find(mvmt_periods>min_length);
    rest_good = find(rest_periods>min_length);

    %% Sample plot
    times = 1/fs:1/fs:length(faceData).*1/fs;
    if plot_fig == 1
        figure() 
        plot(times(1:end-1), mvmt_filt_z)
        hold on
        line([times(1),times(end-1)],[mvmt_thr,mvmt_thr])
        scatter(times(mvmt_inds),ones(length(mvmt_inds),1).*max(mvmt_filt))
        title('Time Course with thresholded movements')
    end

    %% 
    mvmt_good_starts = mvmt_pulses.starts(mvmt_good);
    rest_good_starts = rest_pulses.starts(rest_good);
    
    % Check to make sure none of the ranges fall outside the length of data
    rest_good_starts((rest_good_starts-max_length/2)<1) = [];
    rest_good_starts((rest_good_starts+max_length/2)>length(mvmt)) = [];
    mvmt_good_starts((mvmt_good_starts-max_length/2)<1) = [];
    mvmt_good_starts((mvmt_good_starts+max_length/2)>length(mvmt)) = [];

    mvmt_onset_cnst_range = [mvmt_good_starts-max_length./2;mvmt_good_starts+max_length./2];
    rest_onset_cnst_range = [rest_good_starts-max_length./2;rest_good_starts+max_length./2];
    
    %% Save structure
    face_state = struct();
    face_state.mvmt_cnst_range = mvmt_onset_cnst_range;
    face_state.mvmt_pulses = mvmt_pulses;
    face_state.rest_cnst_range = rest_onset_cnst_range;
    face_state.rest_pulses = rest_pulses;
    face_state.min_sec = min_sec;
    face_state.max_sec = max_sec;
    face_state.fs = fs;
    face_state.mvmt_filt_z = mvmt_filt_z;
    face_state.mvmt_filt = mvmt_filt;

end