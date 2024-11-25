classdef TimeSeries < handle
    % Time series analysis methods for Motion/Pupil traces
    % Apply methods and plot sample traces
    % Frequency analysis: fast fourier transform; wavelet 
    % Dimensionality reduction: PCA; t-SNE, UMAP
    % Clustering of different trace type: k-means, GMM

    properties
        RawTrace    
        RecordingFq
        labels
        UsedTrials
    end

    methods 
        function TraceObj = TimeSeries (RawTraces, labels, fq)
            % Construtor method
            % Filter the traces to not include any all-0 rows or rows w/
            % >10% nan or 0; Input traces should be processed already
            arguments
                RawTraces (1,:) cell % each cell sould contains array or matrix of same length timeseries
                labels      cell 
                fq = 100    % Htz; normal behavioral recordingfrequency
            end

            if numel (labels) ~= numel (RawTraces)
                error ('The number of label sets should match the number of set of traces');
            end
            for i = 1:numel (RawTraces)
                AllRaw = RawTraces{i};  
                ncol = size (AllRaw,2);                 
                rows = sum(AllRaw == 0, 2) <= round (0.5 * ncol); % only use rows (trials) with less than 0.1 of 0
                TraceObj(i).RawTrace = AllRaw;
                TraceObj(i).RecordingFq = fq;
                TraceObj(i).labels = labels{i};
                TraceObj(i).UsedTrials = full(rows);

                fprintf ('There are %d usable time traces found in input trace set %d', sum (TraceObj(i).UsedTrials), i);
            end
        end
        
        function [normalized_trace, rowidx] = Normalize_timeseries(Trace, method, nantolerance, ploton)
            % Normalize single trial traces based on the specified method
            arguments
                Trace   (1,:) TimeSeries 
                method  {mustBeMember(method, {'zscore','MinMaxRange'})}
                nantolerance = 0 % percentage of nan present in data
                ploton  {mustBeMember(ploton, [1,0])} = 0
            end
            normalized_trace = cell (1,numel(Trace));
            for i = 1:numel (Trace)
                temp = full (Trace(i).RawTrace);
                rows = sum( isnan(temp), 2) <= round (nantolerance * size (temp,2)); % only use rows (trials) with less than 0.1 missing data
                rowidx = Trace.UsedTrials & rows;
                waveform = temp(rowidx,:);
                normalized_waveform = zeros (size (waveform));

                for j = 1:numel (waveform(:,1))   
                    switch method
                        case 'zscore'
                            % robust Z-score: (waveform - mean(waveform)) / std(waveform)
                            normalized_waveform(j,:) =  (waveform (j,:) - median(waveform (j,:),'omitmissing')) / iqr(waveform (j,:));  
                        case 'MinMaxRange'
                             % Min-Max [0, 1]: (waveform - min(waveform)) / (max(waveform) - min(waveform)
                            normalized_waveform(j,:) =  normalize(waveform (j,:),'range');
                    end
                    if sum (isnan (normalized_waveform(j,:))) >= round( 0.02*numel (waveform(1,:)))
                        warning ('The %d row contains %d nan values aftr normalization', j, sum (isnan (normalized_waveform(j,:))));
                    end
                end
                normalized_trace{i} = normalized_waveform;
                if ploton
                    plot (normalized_waveform');
                    pause (1)
                end
            end
        end
        
         % ------------------- Frequeny Analysis -------------------%
        
        % function FFT_Timetrace (Trace)
        %     % Fast fourier transform
        %     % trace: 1-by-n cell of trace
        %     % Fs = 100;        % Sampling rate in Hz
        %     numTrials = 1;
        % 
        %     cutoffFreq = 20; % Adjust based on your data
        %     [b, a] = butter(2, cutoffFreq / (Fs / 2), 'low');
        % 
        %     % Initialize matrices
        %     allP1 = [];
        % 
        %     for j = 1:numTrials
        %         % filteredData = filtfilt(b, a, trace{j});
        %         % trialData = filteredData;
        %        % trialData = trace{j};
        %         N = length(trace{j});
        %         t = (0:N-1) / Fs; % t-axis
        %         Y = fft(trialData);
        %         P2 = abs(Y / N);
        %         P1 = P2(1:N/2+1);
        %         P1(2:end-1) = 2 * P1(2:end-1);
        %         f = Fs * (0:(N/2)) / N;
        % 
        %         % Store P1 for group analysis
        %         allP1(j, :) = P1;
        %     end
            
        %     % Compute average spectrum across all trials
        %     avgP1 = mean(allP1, 1);
        % 
        %     % Plot average spectrum
        %     figure;
        %     plot(f, avgP1);
        %     title('Average Single-Sided Amplitude Spectrum Across Trials');
        %     xlabel('Frequency (Hz)');
        %     ylabel('Average |P1(f)|');
        % 
        %     % Identify dominant frequencies
        %     [peaks, locs] = findpeaks(avgP1, f, 'MinPeakHeight', 0.1);
        %     hold on;
        %     plot(locs, peaks, 'ro');
        %     legend('Average Spectrum', 'Dominant Frequencies');
        % end
        
        function timeFreqAnalysis(trialData,Fs)
            [S1, F1, T1] = spectrogram(trialData, 128, 120, 128, Fs); % 128-point window with overlap
            figure;
            surf(T1, F1, abs(S1), 'EdgeColor', 'none');
            axis tight;
            view(0, 90);
            xlabel('Time (s)');
            ylabel('Frequency (Hz)');
            title('STFT - Trial 1');
            
            
            Fs = 100; % Sampling frequency (adjust this to your actual sampling frequency)
            scales = 1:128; % Range of scales for the wavelet transform
            [cwtData, frequencies] = cwt(trialData, 'amor',128); % CWT with frequency output
            
            % Plot the scalogram
            figure;
            imagesc((1:length(trialData)) / Fs, frequencies, abs(cwtData)); % Plot the absolute value of wavelet coefficients
            axis xy; % Ensure the time axis is right-side up
            xlabel('Time (seconds)');
            ylabel('Frequency (Hz)');
            title('Continuous Wavelet Transform (Scalogram)');
            colorbar; % Add color bar to indicate magnitude of coefficients
        end
        
 
        % ----------------------- Dimensionality reduction -------------------%
        function [PCA_results,trialIdx] = tracePCA (TraceObj)
            % Applyinng PCA to the raw traces of the same length; input raw traces
            % PCA: default omit rows with nan values
            arguments
                TraceObj (1,1) TimeSeries
            end
            %%
            % Results
            [normalized_trace, trialIdx] = Normalize_timeseries(TraceObj, 'zscore'); % omit all nan rows
            normalized_trace = normalized_trace {:};
            if size (normalized_trace,2) > size (normalized_trace,1)
                warning ('Number of variables > number of trials or observations; PCA ')
            end
            [CovMatrix,projection,eigenvals,~,explained,est_mean] = pca (normalized_trace); % default SVD
            cumsumExplained = cumsum(explained);
            numDim_90 = find(cumsumExplained >= 95, 1); % first component reaching 90%
            lowD_embedding = projection(:, 1:numDim_90);
            [ndim_bar,prob,chisquare] = barttest(lowD_embedding,0.05); % can't have nan for barlet test
            reconstructedData = lowD_embedding *  CovMatrix(:, 1:numDim_90)' + est_mean;
            PCA_results = struct ('Eigenvals', eigenvals,'VarianceExplained', explained,'Projection',projection,'NumDim_90',numDim_90, ...
                'numDimen_barlette',ndim_bar, 'Barlettest_prob', prob, 'Barlettest_chisqure', chisquare);
            %%
            %%%%%%%%%%%%%%%% plot
            % Subplot 1: Cumulative variance explained with Bartlett test results
            subplot(1, 4, 1);
            plot(cumsumExplained, 'LineWidth', 2); hold on;
            xlim ([1,numDim_90+10])
            xline(numDim_90, 'LineWidth', 2, 'Color', 'r', 'Label', '90% variance');
            xline(ndim_bar, 'LineWidth', 2, 'Color', 'g', 'Label', 'Bartlett test');
            
            % Add a secondary y-axis for Bartlett test values
            yyaxis right;
            plot(1:ndim_bar, prob(1:ndim_bar), 'b--', 'LineWidth', 1.5); % Plot probability
            hold on;
            plot(1:ndim_bar, chisquare(1:ndim_bar), 'k--', 'LineWidth', 1.5); % Plot chi-square
            
            title('Cumulative explained variance by principal components');
            xlabel('Principal components');
            ylabel('Variance explained (%)');
            yyaxis right;
            ylabel('Bartlett Test Results');
            legend('Cumulative explained variance', '90% variance', 'Bartlett test', 'Probabilities', 'Chi-square', 'Location', 'best');
            hold off;
            
            % Subplot 2: 3D PCA embedding
            subplot(1, 4, 3);
            scatter(projection(:, 1), projection(:, 2), 'filled'); 
            axis equal;
            xlabel('1st Principal Component');
            ylabel('2nd Principal Component');
            zlabel('3rd Principal Component');
            title('2D PCA Embedding');
            
            % Subplot 3: Reconstructed Data
            subplot(1, 4,4);
            plot(reconstructedData');
            title(['Data Reconstructed with ', num2str(numDim_90), ' Components (90% Variance)']);
            xlabel('Observation');
            ylabel('Feature Value');
            
            % Print result of number of components
            fprintf('%d number of components explained 90%% variance \n', numDim_90);

        end

        % clustering: use embedding from
        
        % GLM: Predict trials success based on  


    end
end