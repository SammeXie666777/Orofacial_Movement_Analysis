classdef orofacial_mouse < handle
    %   Master script to manage analysis for each mouse
    %   Contain methods for: 
    %   -  1) Motion_energyCalculation; 
    %   -  2) Pupil estimation: 
    %   -  3) Plot functions

    properties
        mouseID         (1,1) string
        phenotype       
        vdlist          (1,:) cell
        PairObj         struct % Contain 3 pairs describing the data struct
        BpodData        
        VideoData        
    end

    methods
        %% ------------------ Methods: Mouse Bio and Prepare Related data -------------
        % --------------- 1) Constructor
        function mouse = orofacial_mouse(mouseID,phenotype)
            arguments 
                mouseID     (1,1) string
                phenotype   {mustBeMember(phenotype,{'MitoPark','Control'})} 
            end
            
            mouse.mouseID = mouseID;
            mouse.phenotype = phenotype;
            mouse.PairObj = struct();
            mouse.PairObj.VdBpodPairObj = PairMapper();
            mouse.PairObj.DateAgePairObj = PairMapper();
            mouse.PairObj.TrialTypePairObj = [];
            mouse.vdlist = {};
            mouse.BpodData = [];
            mouse.VideoData = struct('FaceMotion', [], 'Pupil',[]);
            fd = fieldnames(mouse.VideoData);
            for i = 1:numel(fd)
                mouse.VideoData.(fd{i}) = struct('RawData', [], 'EventData',[]);
            end
        end
        
        % --------------- 2) get or add videos for this mouse; output cell
        function [vdlist,mouse] = getVideo(mouse,varargin)
            if nargin == 1
                fileObj = fileList.pullFilesUserInput(".mp4");
                vdlist = convertFileToCell (fileObj);
            elseif nargin == 2
                vdlist = varargin{1};
            end
            if ~isempty(mouse.vdlist)
                [vdlist,~] = fileList.findDiffFile(mouse.vdlist,vdlist);
            end
            if ~isempty(vdlist)
                mouse.vdlist = [mouse.vdlist, vdlist];  
                mouse.vdlist = sort(mouse.vdlist);
            else
                warning('Obtained new vdlist is the same as stored in mouse obj');
            end
        end

        % --------------- 3) get each BPOD for every video in mouseobj (Overwrite every time)
        function [bpods,mouse] = getBpod(mouse,varargin)
            % Add a utility to autoassign bpod to video (same time? - Aurelie's BPod files)
            if nargin == 1
                bpodDir = uigetdir([],sprintf('Get bpod directory for mouse %s',mouse.mouseID));
            elseif nargin == 2
                bpodDir = varargin{1};
            end
            datepat = '202\d(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])'; % define pattern for YYYYMMDD
            allBpods = dir(fullfile(bpodDir,['*' '.mat']));
            allBpods = allBpods(~startsWith({allBpods.name}, '._'));

            vdList = mouse.vdlist;
            if isempty(vdList)
                error('Get a list of videos for mouse %s first', mouse.mouseID);
            end
            [~, exvdList] = getMappings(mouse.PairObj.VdBpodPairObj);
            if ~isempty(exvdList)
                [vdList,~] = fileList.findDiffFile(exvdList,vdList); % find unmapped videos
            end
            if isempty(vdList)
                warning('No new videos');
                return
            end
            Date = cell(1,numel(vdList));
            bpods = cell(1,numel(vdList));

            for i = 1:numel(vdList) % Unique video that haven't mapped to a bpod
                [~,name,~] = fileparts(vdList{i});
                Date{i} = regexp(name, datepat, 'match');
                trialIdx = cellfun(@(x) contains(x, Date{i}), {allBpods.name});
                if sum(trialIdx) == 0
                    warning(fprintf(' 0 bpod file detected for Da: %s', vdList{i}));
                    continue;
                elseif sum(trialIdx) > 1
                    sprintf('More than one Bpod files detected for current date: %s',Date{i}{:});
                    temp = allBpods(trialIdx);
                    for j = 1:sum(trialIdx)
                        fprintf('Bpod %d is: %s \n',j,temp(j).name)
                    end
                    id = input(sprintf('Which Bpod files to be kept for video %s. Input a single id: ',name));
                    bpods{i} = fullfile(temp(id).folder,temp(id).name);
                else
                    bpods{i} = fullfile(allBpods(trialIdx).folder,allBpods(trialIdx).name);
                end    
            end
            mouse.PairObj.VdBpodPairObj = addMapping(mouse.PairObj.VdBpodPairObj, bpods, vdList);
        end

        % --------------- 4) Get or add the age-week pair data for mouseobj
        function mouse = getAgeDatePair(mouse)
            datepat = '202\d(0[1-9]|1[0-2])(0[1-9]|[12][0-9]|3[01])'; 
            vdList = mouse.vdlist; 
            Date = cell(1,numel(vdList));            
            for i = 1:numel(vdList)
                [~,name,~] = fileparts(vdList{i});
                Date(i) = regexp(name, datepat, 'match'); 
            end
            Date = unique(Date);
            [~, exDate] = getMappings(mouse.PairObj.DateAgePairObj);
            exDate = cellfun(@char, [exDate{:}], 'UniformOutput', false);
            Date = cellfun(@char, Date, 'UniformOutput', false);
            if ~isempty (exDate{1})
                Date = setdiff(Date,exDate);
            end
            Age = cell(1,numel(Date)); 
            for i = 1:numel(Date)
                Age{i} = input(sprintf('Input age for Date %s: ',Date{i}));
                Age{i} = "Week_" + string(Age{i});
            end
            mouse.PairObj.DateAgePairObj = addMapping(mouse.PairObj.DateAgePairObj,Age,Date);
        end

        %% ------------------ Methods: Get BPOD info -------------
        % --------- 5) obtain bpodInfo from BPOD list in Mouse obj; Add
        % bpod data via input bpodlist
        function mouse = defBpod(mouse,bpodlist)
            arguments
                mouse (1,1)   orofacial_mouse
                bpodlist (1,:) cell = {}
            end

            if isempty (bpodlist)
                 [bpodlist, ~] = getMappings(mouse.PairObj.VdBpodPairObj);               
                 if isempty(bpodlist)
                    error('No bpod found associated with mouse, %s', mouse.mouseID);
                 end
            end
         
            % Exclude existing BPod objs stored in mouse
            if ~isempty(mouse.BpodData)
                for i = 1:numel(mouse.BpodData)
                    name = mouse.BpodData(i).name.filename;
                    exBpod{i} = fullfile(name{1},strcat(name{2},name{3}));
                end
                [bpodlist,~] = fileList.findDiffFile(exBpod,bpodlist);
            end

            if ~isempty(bpodlist)
                bpodlist = fileList.translatePath(bpodlist);
                for i = 1:numel(bpodlist)
                    load(bpodlist{i},'SessionData');
                    obj(i) = Bpod(SessionData,0);
                    obj(i) = nameBpod(obj(i),bpodlist(i));
                    if ~isempty(mouse.BpodData)
                        obj(i).trialTypePairObj = mouse.BpodData(1).trialTypePairObj;
                    end
                end
                if isempty(mouse.BpodData)
                    [obj,~] = createPair(obj);
                end
                mouse.BpodData = [mouse.BpodData,obj]; 
                if numel(mouse.PairObj.TrialTypePairObj) == 0
                    mouse.PairObj.TrialTypePairObj = obj(1).trialTypePairObj;
                end
            else
                warning('All bpods in the object or provided Bpods have already stored');
            end
        end  

        % --------- 6) obtain idx from BPOD for interested period
        function [mouse,eventIdx] = getTrialIdx(mouse,onsetState,deltaT,timerIdx,frate)
            arguments
                mouse           (1,1)   orofacial_mouse
                onsetState      string
                deltaT          (1,2) double
                timerIdx        (1,1) {mustBeMember(timerIdx,[1,2])} 
                frate           (1,1) {mustBeInteger} = 100
            end
            bpodObj = mouse.BpodData;
            eventIdx = cell(1,numel(bpodObj));
            for i = 1:numel(bpodObj) 
                fprintf('Index Bpod %d... ',i);
                [bpodObj(i).trials,eventIdx{i}] = idxEventPeriod (bpodObj(i).trials,onsetState,deltaT,timerIdx,frate);
            end           
            mouse.BpodData = bpodObj;
        end  
        
        % --------- 7) Plot trial outcome
        function [mapping,Results] = plotTrialOutcome (mouse,Tpyes,outputFolder)
            arguments
                mouse (1,1) orofacial_mouse
                Tpyes (1,:) cell
                outputFolder = []
            end
            bpodObj = mouse.BpodData;
            name = cell(1,numel(bpodObj));
            for i = 1:numel(bpodObj)
                name{i} = bpodObj(i).name.filename{2};
            end

            if ~isempty(mouse.PairObj.DateAgePairObj)
                [Age,Week] = getMappings(mouse.PairObj.DateAgePairObj) ;
            else
                error('No age-week pairing; Return')
            end

            if isempty (outputFolder)
                outputFolder = uigetdir([],'Get output directory for saving trial outcome figure');
            end

            [mapping,Outcome] = getTrialIdx(bpodObj,Tpyes);
            nAge = numel(Age);
            Results = struct;
            for i = 1:nAge
                temp = false(1,numel(name));
                for d = 1:numel(Week{i})
                    idx = cellfun(@(x) contains(x, Week{i}{d}), name);
                    temp = temp | idx;
                end
                
                for n = 1:numel(Tpyes)
                    idx = Outcome.(Tpyes{n})(temp);
                    Results.(Tpyes{n})(1,i) = sum(cellfun(@sum,idx))/sum(cellfun(@numel, idx));                    
                end
            end
            
            % Plot: Trial Outcome
            figure;
            temp = struct2cell(Results);
            temp = cat(1, temp{:});
            plot(1:nAge,temp,'LineWidth',3,'Marker','o');
            ax = gca; 
            ax.TickLabelInterpreter = 'none';
            xticklabels(Age);
            ax.XAxis.FontSize = 12;
            ax.YAxis.FontSize = 12; 
            xlabel('Age','Interpreter', 'none','FontSize',13,'FontWeight','bold')
            ylabel('Outcome ratio','FontSize',13,'FontWeight','bold');
            ylim([0 1]);
            legend(Tpyes);
            title (sprintf('Trial outcome of %s mouse: %s',mouse.phenotype,mouse.mouseID),"FontSize",15,"FontWeight","bold");
            figpath = fullfile(outputFolder,sprintf('%s_TrialOutcome',mouse.mouseID));
            saveas(gcf,figpath,'fig');
            close gcf;             
        end

        % ----------- 7) Plot reaction time to first touch when reward
        % present
        function ReactionTime = plotReactionTime (mouse, states)
            arguments
                mouse (1,1) orofacial_mouse
                states (1,2) cell = {'RewardResponse','PostRewardPeriod'} 
            end
            %%
            bpods = mouse.BpodData;

            name = cell(1,numel(bpods));
            for i = 1:numel(bpods)
                name{i} = bpods(i).name.filename{2};
            end

            if ~isempty(mouse.PairObj.DateAgePairObj)
                [Age,Week] = getMappings(mouse.PairObj.DateAgePairObj) ;
            else
                error('No age-week pairing; Return')
            end
            ReactionTime = cell (1,numel (bpods));
            for i = 1:numel (bpods)
                ReactionTime{i} = idxPeriod (bpods(i).trials,states,1,[1,1]);
            end
            avg_recT = zeros (1,numel (Age));
            std_recT = zeros (1,numel (Age));
            
            for i = 1:numel (Age)
                %temp = false(1,numel(name));
                T = [];
                for d = 1:numel(Week{i})
                    idx = cellfun(@(x) contains(x, Week{i}{d}), name);
                    %temp = temp | idx;
                    T = [T, ReactionTime{idx}];  %horizontally concatenate recT for one week
                end
                avg_recT(i) = mean (T(~isnan(T)));
                std_recT(i) = std(T(~isnan(T)));
            end

            figure;
            plot (1: numel(Age), avg_recT,'LineWidth',3,'Marker','o')
            hold on;
            errorbar(avg_recT,std_recT,'LineWidth',2)
            ax = gca; ax.TickLabelInterpreter = 'none';
            xticks (1: numel(Age)); xticklabels(Age);
            ax.XAxis.FontSize = 12; ax.YAxis.FontSize = 12; 
            xlabel('Age','Interpreter', 'none','FontSize',13,'FontWeight','bold')
            ylabel('Reaction Time (s)','FontSize',13,'FontWeight','bold');
            legend('Mean Reaction Time (s)','Std');
            title (sprintf('Reaction time of %s mouse: %s',mouse.phenotype,mouse.mouseID),"FontSize",15,"FontWeight","bold");
        end
        
        % ------------ helper function: identify the position idx of a
        % video based on date by checking mapping of vd and bpod
        function id = dispVdID (mouse,date)
            arguments
                mouse (1,1) orofacial_mouse
                date (1,:) cell
            end
            vds = mouse.vdlist;
            if isempty (vds)
                error ('Use getvideo function to obtain all the videos for current mouse obj');
            end
            id = cell (size (date));
            for i = 1:numel (date)
                id{i} = find(contains(vds, date{i}));
                if ~isempty(id{i})
                    fprintf('The video idx for date %s is %s.\n', date{i}, num2str(id{i}));
                else
                    fprintf('No video found for date %s\n', date{i});
                end
            end
        end
        %% ------------------ Methods: Orofaial movement -------------
        % ------------ 8) Calculate raw face motion
        function [raw_face,mouse] = getFaceMotion(mouse,vdlist,numFrameTrial,gamma,ROI,ROIWidthHeight,outputFolder)            
            % Save raw face trace of each video to an individual mat file
            arguments
                mouse           (1,1) orofacial_mouse
                vdlist          (1,:) cell
                numFrameTrial   (1,:) cell  % each cell (video) contain a 1-by-ntrial array, each element numFrames
                gamma           (1,:) double = 1  
                ROI             (1,:) cell = []
                ROIWidthHeight  (1,2) = {[150,150], [100,100]} % face and background
                outputFolder    {mustBeMember(outputFolder,[0,1])} = 1 
            end
            ID = mouse.mouseID;    
            vdlist = fileList.translatePath(vdlist);
            if gamma == 1
                gamma = ones (1,numel(vdlist) );
            end
            
            disp ('Get output directory for saving face_stats structure');
            if outputFolder == 1
                outputFolder = uigetdir([],'Get output directory for saving face_stats structure');
            end
            if numel(numFrameTrial) ~= numel(vdlist) || length(gamma) ~= numel(vdlist) 
                error('Number of event cells must equal num of videos');
            end

            if isempty (ROI)
                ROI = cell(1,numel(vdlist));                
                for i = 1:numel(vdlist)
                    ROI{i} = GUI_Cropping(vdlist{i}, ROIWidthHeight, {'face','bg'}, 0);
                end 
                if outputFolder == 1
                    save (fullfile (outputFolder,strcat(ID, '_Face_ROI.mat')),"ROI");
                end
            elseif numel (ROI) ~= numel (vdlist)
                error('Number of ROI input must equal num of videos');
            end
            
            % Face_stats calculation
            raw_face = cell (1,numel(vdlist));
            for i= 1:numel(vdlist)
                [~,name,~] = fileparts (vdlist{i});
                temp = strsplit(name,'_');
                fdname = strjoin([ID(:) temp{end-2:end}],'_');
                raw_face_trace = MotionEnergyCalculation (vdlist{i},ROI{i},numFrameTrial{i},gamma(i));

                if isfield(mouse.VideoData.FaceMotion.RawData,fdname) % store face data under each vd       
                    warning('Video %s has already been processed for face motion',fdname);
                else
                    mouse.VideoData.FaceMotion.RawData.(fdname) = raw_face_trace; % field: ROI, VdPath, BpodVideoNframeDiff, RawTrace, Medfilt1Trace
                    raw_face{i} = raw_face_trace;
                    if outputFolder ~= 0
                        fileN = fullfile(string(outputFolder),strcat(fdname, '_RawFaceTrace.mat'));
                        save(fileN,"raw_face_trace");
                    end
                end
            end           
        end
        
        %% ------------------ Methods: Pupil estimation -------------
        function [rawData,mouse] = getPupil(mouse,p_threshold,methods,plot_on,outputFolder)
            % 9) Calculate pupil diameter from DLC .h5 files
            % 1. convert h5 to mat
            % 2. Infer pupil diameter and eyelid_distance

            arguments
                mouse           (1,1) orofacial_mouse
                p_threshold     (1,1) double
                methods         {mustBeMember(methods,{'fit_circle','median_dist'})}
                plot_on         {mustBeMember(plot_on,[0,1])} = 1
                outputFolder    {mustBeMember(outputFolder,[0,1])} = 1 
            end

            disp ('Get directory containing config (yaml) file')
            configpath =  uigetdir([],sprintf('Get directory for confg (yaml) file'));
            disp('Get .h5 directory');
            h5dir = uigetdir([],sprintf('Get .h5 directory'));
            DLC_h5_to_Mat (h5dir,configpath,'direc');
            
            % excluded analyzed pupil data
            cd(h5dir); matList = dir('*.mat');
            matList = matList(contains({matList.name}, mouse.mouseID)); % only this ID 
            matList = fullfile({matList.folder}, {matList.name}); % Full file paths
            if ~isempty (mouse.VideoData.Pupil.RawData) % exclued analyzed mat files
                pastMat = fieldnames (mouse.VideoData.Pupil.RawData); 
                isIncluded = false(size(matList));
                for i = 1:numel(matList)
                    isIncluded(i) = any(cellfun(@(x) contains(matList{i}, x), pastMat));
                end
                matList = matList(~isIncluded);
            end
            if isempty (matList)
                warning ('All videoes have been processed as stored in animal object; terminated');
                return;
            end
            [Output,rawData] = pupil_Infer_DLC(matList,methods,p_threshold,plot_on); 
            mouse.VideoData.Pupil.RawData = Output; 
            if outputFolder == 1
                disp('All video processed, saving data. ')
                outputFolder = uigetdir([],'Get output directory for saving raw pupil data structure');
                t = datestr(now, 'yyyymmdd_HHMMSS');
                fileN = fullfile(outputFolder,strcat(mouse.mouseID, '_RawDLCTracker_', t, '.mat'));
                save(fileN,"rawData");
            end
        end
        

    end
 
     
    methods (Static)
        %% ------------------  Event alignment methods: 
         % ------------------- get event data from raw data and plot with that event (NOTE: not selected by outcome type)
         function [EventTrace,parsed] = AlignRawWithEvent (rawData,eventIdx,identifier,tracetype,outputFolder, ntimepoints)
             % EventTrace: structure with vdlist name; each subfield
             % contains matrix of ALL trials - all-0 rows if no event
             arguments
                rawData     struct % with field vdname.RawTrace or FilteredTrace
                eventIdx    (1,:) cell % each cell contains sparse array for trials to be considered
                identifier  {mustBeMember(identifier,{'FaceMotion','Pupil','Nose'})}
                tracetype   {mustBeMember(tracetype,{'RawTrace','FilteredTrace','NorTrace'})} = 'FilteredTrace'
                outputFolder {mustBeMember(outputFolder,[0,1])} = 1 
                ntimepoints (1,1) = 601 % Based on the time points indexed from bpod
            end
            
            vdlist = fieldnames(rawData);
            if numel(eventIdx) ~= numel(vdlist)
                error('Number of event cells must equal num of raw data');
            end
            if outputFolder == 1
                outputFolder = uigetdir([],'Get output directory for saving face_stats structure');
            end
            
            %ncol = length(nonzeros(eventIdx{1}{1}));
            ncol = ntimepoints;
            % Initialize two output
            EventTrace = struct;
            parsed = struct;
            for i = 1:numel(vdlist) % For each video
                fprintf('Process video data: %s. \n', vdlist{i})
                if ~isfield (rawData.(vdlist{i}), tracetype)
                    warning ('%s has no %s trace processed',vdlist{i}, tracetype)
                    continue;
                end
                raw = rawData.(vdlist{i}).(tracetype);                  
                nTrial = numel(eventIdx{i});                
                vdi = eventIdx{i};  % Assuming eventIdx{i} is sparse
                if ~iscell(raw)     % Pupil raw trace divided into trials
                    bpodlg = cellfun(@length, vdi);
                    diff = abs(sum(bpodlg) - length(raw));
                    fprintf('Number of frames in the video data diff from bpod count by %d. \n',diff);
                    if diff > 100
                        warning('Frame counts diff too much between video data and bpod')
                        continue
                    else
                        bpodlg(end) = bpodlg(end) - diff;
                    end
                    raw = mat2cell(raw, 1, bpodlg);
                    parsed.(vdlist{i}).(tracetype) = raw;
                end

                rowIndices = []; colIndices = []; values = [];
                
                for j = 1:nTrial                
                    [~, cols, ~] = find(vdi{j});  % Get non-zero column indices for the j-th trial
                    
                    if length(cols) == ncol
                        vec = raw{j}(cols);   
                        rowIndices = [rowIndices; repmat(j, 1, ncol)']; % Repeat the row index j for each column
                        colIndices = [colIndices; (1:ncol)'];          % Column indices 1 to ncol
                        values = [values; vec'];                       % The corresponding values
                    end
                end
                tempE = sparse(rowIndices, colIndices, values, nTrial, ncol); 
                EventTrace.(vdlist{i}) = tempE;

                if outputFolder ~= 0  % Plot all non-zero traces that potentialy have nan elements
                    fulltemp = full(tempE);
                    rownan = NaN(1, ncol); rowzero = zeros(1,ncol);
                    traces = fulltemp(~ismember(fulltemp,rownan,"rows") & ~ismember(fulltemp,rowzero,"rows"),:) ;                    
                    if ~isempty(traces)
                        figure;
                        plot(traces');
                        xlim([1,ncol]);
                        title(sprintf('All traces from %s',vdlist{i}));
                        saveas(gcf,fullfile(outputFolder,strcat(vdlist{i}, '_AllRawTraces_', identifier)),'fig');
                        close all;
                    else
                        fprintf('No valid data for %s',vdlist{i});
                    end
                end
            end
         end

        % --------------- get diff types of trials and PLO +/- avg traces and raw traces used for averaging
        function [Stats,idx] = TrialTypeBasedStats(EventTrace,TrialIdx,identifier,trialTypeName,eventName, outputFolder,frate)
            arguments
                EventTrace  struct
                TrialIdx    (1,:) cell
                identifier  {mustBeMember(identifier,{'FaceMotion','Pupil','Nose'})}
                trialTypeName {mustBeMember(trialTypeName,{'Reaching','NoReach','EarlyReach'})}
                eventName   {mustBeMember(eventName,{'RewardOut','Baseline','SpoutTouch'})} = 'RewardOut'
                outputFolder{mustBeMember(outputFolder,[0,1])} = 1 
                frate       (1,1) double = 100
            end
            if outputFolder == 1
                outputFolder = uigetdir([],'Get output directory for saving face_stats structure');
            end

            vdlist = fieldnames(EventTrace);
            idx = cell(1,numel(vdlist));
            if numel(vdlist) ~= numel(TrialIdx)
                error('Number of input tiral idx not equal number of processed vds in EventTrace');
            end
            Stats = struct;
            for i = 1:numel(vdlist) % For each video
                tempE =  EventTrace.(vdlist{i});   
                tempE = full(tempE); % from sparse to matrix
                ValidTrial = tempE(any(tempE, 2) & (TrialIdx{i})', :); % Trials both with existing data and correct trial type
                idx{i} = any(tempE, 2)& (TrialIdx{i})';
                Stats.(vdlist{i}).ValidTrialID = idx{i};   % logic idx of valid trial

                if isempty(ValidTrial)
                    warning('There is no valid trial for %s; Plotting skipped',vdlist{i});
                    continue;
                end
                eventAvg = mean(ValidTrial, 1, 'omitnan'); % existing nan could be blinking in one frame
                eventStd = std(ValidTrial, 0, 1, 'omitnan');
                eventSEM = eventStd ./ sqrt(sum(~isnan(ValidTrial), 1)); 

                Stats.(vdlist{i}).eventStats = [eventAvg;eventSEM];
                if outputFolder ~= 0 % Plot Avg motion traces and all traces
                    figName = fullfile(outputFolder,strcat(vdlist{i}, '_AvgTraces_',trialTypeName,'_',identifier));   
                    figtitle = cellfun(@(x, y) strcat(x, '_', y), string(trialTypeName), string(eventName), 'UniformOutput', false);
                    orofacial_mouse.StatsPlot( Stats.(vdlist{i}),frate,figName,identifier,figtitle{:} );
                    plot(ValidTrial');
                    xlim([1,size(ValidTrial, 2)])
                    title(sprintf('Raw traces for averaging %s trials from %s',trialTypeName, vdlist{i}));
                    saveas(gcf,fullfile(outputFolder,strcat(vdlist{i}, '_RawTracesForAvg_',trialTypeName,'_', identifier)),'fig');
                    close all;
                end
            end
        end


        function [AllTraces, labels] = combineAllTraces (DataStructure, optLabel)
            % combine all data traces into one matrix; DataStructure needs
            % to contain subfield with matrix of same nCol 
            arguments
                DataStructure   struct % structure w/ one layer of subfield
                optLabel        cell = {} % just one identifier for the whole Datastructure
            end
            % Check num of columns for each matrix
            fieldN = fieldnames(DataStructure);
            numCols = cellfun(@(f) size(DataStructure.(f), 2), fieldN);
            if numel(unique(numCols)) > 1
                error('All matrices must have the same number of columns.');
            end

            AllTraces = []; labels = {};
            totalRows = 0;
            
            % Loop through each subfield in the structure
            for i = 1:numel(fieldN)
                currentMatrix = DataStructure.(fieldN{i});
                if ~issparse(currentMatrix)
                    currentMatrix = sparse(currentMatrix);
                end                
                AllTraces = [AllTraces; currentMatrix];
                numRows = size(currentMatrix, 1);
                totalRows = totalRows + numRows;
                currentLabel = [fieldN(i),optLabel];
                labels = [labels; repmat(currentLabel, numRows, 1)];
            end
            disp(['Total number of rows in AllTraces: ', num2str(totalRows)]);
        end

        %% ---------- Plotting methods
        % ------------------- Plot and align traces with raw video
        function AlignVdTrace(data,EventIdx,TrialIdx,allTrial,trialTypeName,ds,vddir)  
            % Align all kind of trial-based trace data to raw videos
            % Input: data.(vdname)
            arguments
                data            struct % struct containng
                EventIdx        (1,:) cell
                TrialIdx        (1,:) cell
                allTrial        (1,1) double
                trialTypeName   string
                ds              (1,1) double = 10
                vddir           {mustBeMember(vddir,[0,1])} = 1
            end

            vdlist = fieldnames(data);
            fprintf('Data from videos:\n %s\n', strjoin(vdlist, '\n'));
            if numel(vdlist) ~= numel(EventIdx) % TrialIdx should match the order/# of video
                error('Number of valid trial different from vdlist')
            end
            
            if vddir
                disp('Get video directory where raw videos are saved.')
                vddir = uigetdir([],'Get video directory for aligning videos');
            end
            disp('Get directory to save output.')
            outputFolder = uigetdir([],'Get output directory for saving aligned video');
            tic;
            for i = 2:numel (vdlist)
                fprintf("Process video %s \n",vdlist{i})
                cd(vddir); allvd = dir('*.mp4');
                idx =  cellfun(@(x) contains(x, vdlist{i}) && contains(x, '_labeled') && ~contains (x, '_pupilaligned') && ~contains (x, 'extractframes'), {allvd.name});         
                movieObj = VideoReader(allvd(idx).name);
                tempD = data.(vdlist{i}).FilteredTrace; %% Could change this structure
                tempEvent = EventIdx{i};  tempTrial = TrialIdx{i};
                frameIdx =cumsum([1, cellfun(@length, tempEvent)]); % cumsum to get start frame ID
                
                if allTrial ~= 0 % if allTrial is not 0; select n trials from valid trials 
                    n = allTrial; % write n trials
                    pos = find(tempTrial);
                    if length(pos) >= n
                        tempTrial = false(size(tempTrial));
                        tempTrial = tempTrial(pos(randperm(length(pos), n)));
                    end
                end

                for j = 1:numel(tempEvent) % plot for valid trial
                    if tempTrial(j) % if current trial valid
                        wholeTrialdata = tempD{j};
                        startFrame = frameIdx(j);
    
                        outputName = fullfile(outputFolder,sprintf('%s_%s_trial%d',vdlist{i},trialTypeName,j));
                        ROI = [];
                        if isfield(tempD,'ROI')
                            ROI = tempD.ROI;
                        end
                    
                        orofacial_mouse.displayMotion(movieObj, outputName, ROI, wholeTrialdata, startFrame, tempEvent{j},ds)  
                        fprintf('Finish writing trial %d. \n',j);
                    end
                end
                clearvars movieObj 
                t= toc; fprintf('Runtime for %s: %d(s). \n',vdlist{i},t);
            end
        end

        
        % ------------------- Plot avg traces  +/- SEM
        function StatsPlot(stats,frate,figName,identifier,eventName)
            eventAvg = stats.eventStats(1,:);
            eventSEM = stats.eventStats(2,:);
            nTrial = sum(stats.ValidTrialID);
            deltaTime = length(eventAvg)/frate/2;
            tMark = linspace(-deltaTime,deltaTime,length(eventAvg));
            figure;
            plot(tMark,eventAvg,LineWidth=1,Marker=".");
            hold on;
            fill([tMark, fliplr(tMark)], ...
             [eventAvg + eventSEM, fliplr(eventAvg - eventSEM)], ...
             'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none', 'LineWidth', 2);
            xlim([-deltaTime, deltaTime]);
            numTicks = 11;
            xticks(linspace(-deltaTime, deltaTime,numTicks));
            xlabel('Event time (s)');
            ylabel(sprintf('Smoothed %s (arbiturary unit)',identifier));

            title(sprintf('Change in %s around event: %s',identifier,eventName),'Interpreter', 'none');
            yPosition  = max(eventAvg)+min(eventSEM);
            text(-deltaTime,yPosition,sprintf('Averaged over %d trials',nTrial),"FontSize",12);
            legend('Mean', '±1 Standard Error');
            hold off;
            saveas(gcf,figName,'fig');
            close all;
        end
       
        % ------------------- Display movie along with traces
        function displayMotion(movieObj, outputName, ROI, wholeTrialdata, startFrame, EventIdx,ds)
            % ROI: structure with fields for each ROI, each containing x, y, width, height        
            if isempty(ds)
                ds = 10;  
            end
            vidfile = VideoWriter(outputName, 'MPEG-4');
            vidfile.FrameRate = round(movieObj.FrameRate / ds);
            open(vidfile);   
           figure('Visible', 'off');
        
            % Read the first frame and get its size for aspect ratio
            firstFrame = read(movieObj, startFrame);
            [frameHeight, frameWidth, ~] = size(firstFrame);
        
            % Set the figure size and aspect ratio
            screenSize = get(0, 'ScreenSize');
            figHeight = screenSize(4) * 0.9; % 90% of screen height
            %figWidth = frameWidth / frameHeight * figHeight;
            set(gcf, 'Position', [100, 100, screenSize(3), figHeight]);
        
            % Create a top subplot for the video with the original aspect ratio
            ax1 = subplot(2, 1, 1);
            set(ax1, 'Position', [0.1, 0.5, 0.8, 0.4]); % Adjusted to a fixed portion of the figure
            image(firstFrame);
            axis off;
            axis image; % Maintain original aspect ratio
            hold on;
            if ~isempty(ROI)
                roiNames = fieldnames(ROI);
                for i = 1:length(roiNames)
                    roi = ROI.(roiNames{i});
                    r = drawrectangle('Position', [roi.x, roi.y, roi.width, roi.height], 'Label', roiNames{i}, 'Color', 'r', 'LineWidth', 2);
                    set(r, 'LabelVisible', 'hover');  % Label will appear when hovered over
                end  
            end
            
            [~, name, ~] = fileparts(outputName);
            title(name, 'Interpreter', 'none');
            ax2 = subplot(2, 1, 2);
            set(ax2, 'Position', [0.1, 0.1, 0.8, 0.3]); % Bottom part, fixed height for rectangular plot
            time = linspace(1, length(wholeTrialdata(1,:))/movieObj.FrameRate, length(wholeTrialdata(1,:))); % x-time label
            plot(time, wholeTrialdata', 'LineWidth', 2);
            ylabel('Smoothed motion data for one trial');
            hold on;
        
            % Face event trace and center vertical line
            eventData = wholeTrialdata(:,logical(EventIdx));
            eventStartT = find(EventIdx~=0); eventStartT = eventStartT(1);
            timeEvent = linspace(time(eventStartT), time(eventStartT + length(eventData) - 1), length(eventData));
            plot(timeEvent, eventData, 'LineWidth', 3);   
            xline(time(eventStartT + round(length(eventData) / 2)), '--r', 'center', ...
                'LabelVerticalAlignment', 'top', 'LabelHorizontalAlignment', 'center');            
            h1 = plot(1, wholeTrialdata(1,1), 'mo', 'MarkerFaceColor', 'm', 'MarkerSize',8,'YDataSource', 'Y', 'XDataSource', 'X');
            allidx = startFrame:startFrame + length(wholeTrialdata(1,:)) - 1;
        
            for frame = 1:ds:length(wholeTrialdata(1,:))
                thisFrame = read(movieObj, allidx(frame));       
                % Ensure the frame has consistent dimensions
                if size(thisFrame, 1) ~= frameHeight || size(thisFrame, 2) ~= frameWidth
                    error('Frame dimensions do not match expected dimensions.');
                end
        
                subplot(ax1)
                image(thisFrame);
                axis off;
                axis image; % Maintain original aspect ratio
                hold on;
        
                % ROI
                if ~isempty(ROI)
                    for i = 1:length(roiNames)
                        roi = ROI.(roiNames{i});
                        r = drawrectangle('Position', [roi.x, roi.y, roi.width, roi.height], 'Label', roiNames{i}, 'Color', 'r', 'LineWidth', 2);
                        set(r, 'LabelVisible', 'hover');  % Label will appear when hovered over
                    end
                end
                hold off;
        
                subplot(ax2)
                X = time(frame);
                Y = wholeTrialdata(1,frame);
                refreshdata(h1, 'caller');
                set(gca, 'ytick', []);
                title('Change in behaviors around event');
                xlabel('Time (s)')        
                drawnow; 
                F = getframe(gcf);
                writeVideo(vidfile, F);
            end
            close(vidfile);
            delete (gcf);
        end


    end
end
    
