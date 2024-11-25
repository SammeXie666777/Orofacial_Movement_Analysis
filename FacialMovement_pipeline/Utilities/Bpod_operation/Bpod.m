classdef Bpod < handle
    % Define individual Bpod object and relevant methods 
    properties 
        name                
        nTrials             (1,1) double        % num trials
        trials              (1,:) Trial         % Trial-wise objects
        trialTypes                              % Assign trial types
        trialTypePairObj                        % Trial-type objects 
    end

    %%
    methods 
        % --------------- Constructor: Create one Bpod obj from Session data
        function bpodObj = Bpod(SessionData,createPairorNot,type)
            % Initi. nTrials, RawEvents, trialTypes, trialTypePairObj 
            arguments 
                SessionData     (1,1) struct 
                createPairorNot {mustBeMember(createPairorNot,[0,1])} = 1
                type            (1,:) cell = {'Outcome','TrialTypes'}                
            end
            % nTrials and Name
            bpodObj.nTrials = SessionData.nTrials;
            bpodObj.name = struct();
            % trialTypes
            default = {'Outcome','TrialTypes'};
            bpodObj.trialTypes = struct();
            if all(ismember(default, type)) ||  all(isfield(SessionData,default ))                
                bpodObj.trialTypes.Outcome = SessionData.Outcome;
                bpodObj.trialTypes.TrialTypes = SessionData.TrialTypes;
            else
                error('Missing fields in the SessionData: Outcome and TrialTypes')
            end
            opt = setdiff(default,type);
            if ~isempty(opt)
                for i = 1:numel(opt)
                    if isfield(SessionData,opt{i})
                        bpodObj.trialTypes.(opt{i}) = SessionData.(opt{i});
                    else
                        warning('field %s not found in seesion data, skipped',opt{i});
                    end
                end
            end 

            % Create Type Obj pair
            bpodObj.trialTypePairObj = struct();
            if createPairorNot
                [bpodObj,~] = createPair(bpodObj,namePairorNot);
            end

            % Create Trial objs
            nTrial = numel(SessionData.RawEvents.Trial);
            for i = 1:nTrial
                bpodObj.trials(i) = Trial(SessionData.RawEvents.Trial(1,i)); 
            end
            bpodObj.trials = defineTrialType(bpodObj.trials,bpodObj.trialTypes);
            bpodObj.trials = assignID(bpodObj.trials,1:nTrial);
            bpodObj.trials =  SpoutTouch (bpodObj.trials);
        end
        
        % --------------- Method: Store name of the bpod file
        function bpodObj = nameBpod (bpodObj,path)
            arguments
                bpodObj (1,1) Bpod
                path    (1,1)  
            end
            [dir,filename,ext] = fileparts(string(path));
            parts = strsplit(filename, '_');
            bpodObj.name.filename{1} = dir; 
            bpodObj.name.filename{2} = filename; 
            bpodObj.name.filename{3} = ext; 

            bpodObj.name.mouseID = parts{1};
            bpodObj.name.date = parts{end-1};
            bpodObj.name.time = parts{end};
            fprintf('Working on bpod %s\n',filename);
        end

        % --------------- Method: Create trialtype-name pair for multiple bpods;
        % assuming every bpod the same trials types
        % Need to find a representative Bpod with all types
        function [bpodObj,pair] = createPair(bpodObj,repBodID)
            arguments
                bpodObj         (1,:) Bpod
                repBodID (1,1) {mustBeInteger} = 1
            end
            % Method: Create trial type pair obj
            tp = bpodObj(repBodID).trialTypes;
            tpname = fieldnames(tp);
            fprintf('Field names: %s\n', strjoin(tpname, ', '));
            disp('Start to match the id to naming; Make sure all bpods input have the same types');
            for i = 1:numel(tpname)
                fldname = strjoin({tpname{i},'PairObj'},'');
                inputN = [];
                uniqID = unique(tp.(tpname{i}));
                %inputN = cell(1,size(uniqID));
                for j = 1:numel(uniqID)
                    prompt = sprintf('Enter the type name corresponding to ID %d for field %s: ', uniqID(j), tpname{i});
                    inputN{j} = input(prompt, 's');  % Store the input as a string
                end
                yn = input('Is that all the unique ID for this field (y/n): ','s');
                if strcmp(yn,'n')
                    tempID = input('ID not shown in this BPOD: (e.x. [1,4]): ');                  
                    for n = 1:length(tempID)
                        tempN{n} = input(sprintf('Corresponding name to the ID %d: ',tempID),'s');
                    end
                    uniqID = [uniqID,tempID];
                    inputN =  [inputN,tempN];
                end               

                Pobj = PairMapper();
                Pobj = addMapping(Pobj, inputN, num2cell(uniqID));
                pair.(fldname) = Pobj;                  
            end
            
            for i = 1:numel(bpodObj)
                bpodObj(i).trialTypePairObj = pair;
            end
        end

        % -------------------- Method: get idx for interested trial types;
        % NOTE: require user input
        function [ids,output] = getTrialIdx(bpodObj,typnames)
            % idx: logic idx of either 0 or 1-by-n logic array
            arguments
                bpodObj     (1,:) Bpod
                typnames    (1,:) cell 
            end
            for i= 1:numel(bpodObj)
                if numel(fieldnames(bpodObj(i).trialTypePairObj)) == 0
                    error('Pair id with outcome firts using function createPair');
                end
            end
            ids = struct;
            obj = bpodObj(1).trialTypePairObj;      % Assuming the same pair for every bpodObj
            % User input for trial types
            tyn = fieldnames(obj);
            for n = 1:numel(typnames)
                fprintf('Select trial types for: %s .... \n',typnames{n});
                for i = 1:numel(tyn)
                    pairobj = obj.(tyn{i});
                    fprintf('Display %s',tyn{i});
                    displayMappings(pairobj);
                    ids.(typnames{n}).(tyn{i}) = input('Select the id(s) for trials to be included (ex: [1,2,3]): ');
                    getOutcome(pairobj, num2cell(ids.(typnames{n}).(tyn{i})));
                end
            end

            output = struct;
            for n = 1:numel(typnames)
                idflag = fieldnames(ids.(typnames{n}));            
                idx = cell(1,numel(bpodObj));
                for i = 1:numel(bpodObj)  
                    alltys = fieldnames(bpodObj(i).trialTypes);
                    idx{i} = true(1,bpodObj(i).nTrials);
                    for j = 1:numel(alltys)
                        temp = ~cellfun('isempty', strfind(idflag, alltys{j}));
                        temp = ismember(bpodObj(i).trialTypes.(alltys{j}), ids.(typnames{n}).(idflag{temp})); 
                        idx{i} = idx{i} & temp;
                    end
                end
                output.(typnames{n}) = idx;
            end
        end

        
   
        
    end

end


