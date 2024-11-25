classdef Trial < handle
    %   Define a trial obj 
    %   Frame based indexing; Not duration
    properties
        numFrame      (1,1) double {mustBeInteger}  % Double
        dur           (1,1) double                  % Double
        TrialID       %(1,1) double {mustBeInteger}  % Double: ID in the Bpod
        TrialType     struct                        % Structure
        RawSpoutTouch  
        idxframe        
        RawState      % Raw state data
    end

    methods
        function obj = Trial(RawTrial)
            arguments
                RawTrial (1,1) cell
            end
                data = RawTrial{1};
                if all(isfield(data,{'Events','States'}))   
                    if isfield(data.Events, 'GlobalTimer1_End')
                        obj.numFrame = length(data.Events.GlobalTimer1_End);
                    else
                        error('GlobalTimer1_End is missing in the Events structure');
                    end
                    obj.dur = data.States.TimerEnd(2); % ???? (is this right)    
                    obj.TrialID = NaN;
                    obj.RawState = data.States;
                    obj.TrialType = struct();               
                    obj.idxframe = [];
                    obj.RawSpoutTouch = data.Events;
                else
                    warning('The trial doesnt contain Events or States structure; Return empty trial obj')
                    obj = [];
                end

        end

        %-------- Method: Define and Overwrite trial ID
        function trialObj = assignID(trialObj,id)
            arguments
                trialObj (1,:) Trial
                id       (1,:) double
            end
            for i = 1:numel(trialObj)
                if ~isnan(trialObj(i).TrialID)
                    warning('The %d trial obj already assigned an id; overwriting',i);
                end
                trialObj(i).TrialID = id(i);
            end
        end

        %-------- Method: Assign types to trial as a structure 
        function trialObj = defineTrialType(trialObj,tpNameIDStrut)
            arguments
                trialObj        (1,:) Trial
                tpNameIDStrut   struct
            end
            typename = fieldnames(tpNameIDStrut);
            for i = 1:numel(typename)
                idt =tpNameIDStrut.(typename{i});
                for j = 1:numel(trialObj)
                    trialObj(j).TrialType.(typename{i}) = idt(j);
                end
            end
        end
        
        %--------- Method: output 1-by-ntrial cell containing spares arrays for each trial
        function [trialObj,eventIdx] = idxEventPeriod (trialObj,onsetState,deltaT,timerIdx, frate,naming)
            % get eventIdx for all trials; NOT differentiated by outcomes;
            % eventIdx{i}: sparse array (nTrial,deltaT*2+1) - all-0 row if
            % state non-existent OR state NaN value
            arguments
                trialObj        (1,:) Trial 
                onsetState      string
                deltaT          (1,2) double % [time before, time after]
                timerIdx        (1,1) {mustBeMember(timerIdx,[1,2])} 
                frate           (1,1) {mustBeInteger} 
                naming          (1,1) = 0 % or name for the event
            end 
            eventIdx = cell(1,numel(trialObj));
            onsetState = string(onsetState);
            if naming == 0
                naming = onsetState;
            end
            naming = string(naming);
            
            deltaT = sort (deltaT);
            for i = 1:numel(trialObj)
                eventIdx{i} = sparse(1,trialObj(i).numFrame); 
                rawSt = trialObj(i).RawState;
                if isfield(rawSt,onsetState) && ~any(isnan(rawSt.(onsetState)))
                    rangeSize = round((deltaT(2) - deltaT(1)) * frate) + 1;
                    
                    tp = rawSt.(onsetState)(timerIdx); % select end of timer
                    lower = max(floor((tp + deltaT(1)) * frate), 1);
                    upper = min(floor((tp + deltaT(2)) * frate), trialObj(i).numFrame);

                    if upper - lower + 1 ~= rangeSize
                        warning('Trial %d index period does not match expected range size; adjusting bounds', i);
                        if lower < 1
                            lower = 1;
                            upper = lower + rangeSize - 1;
                        elseif upper > trialObj(i).numFrame
                            upper = trialObj(i).numFrame;
                            lower = upper - rangeSize + 1;
                        end
                    end
                    if length(lower:upper) == rangeSize
                        eventIdx{i} = sparse(1, lower:upper, 1, 1, trialObj(i).numFrame);
                    else
                        warning('Trial %d is indexed with incorrect number of frames; skipped', i);
                    end
                else
                    fprintf('The %s is not a field of trial %d; skipped \n',onsetState,i);
                end
                trialObj(i).idxframe.(naming) = eventIdx{i};
            end
        end
        
        %--------- Method: idx irregular period 
        function delT = idxPeriod (trialObj,twoStates,frate, pos_idx)
            arguments
                trialObj        (1,:) Trial 
                twoStates       (1,2) cell
                frate           (1,1) {mustBeInteger} = 1 % in units of second
                pos_idx         (1,2) = [1,2] % position of start and end states
            end   
            startS = char(twoStates{1});
            endS = char(twoStates{2});
            delT = NaN(1,numel(trialObj));
            for i = 1:numel(trialObj)
                rawSt = trialObj(i).RawState;
                if all(isfield(rawSt,{startS,endS}))   
                    startST = rawSt.(startS)(pos_idx(1));
                    endST = rawSt.(endS)(pos_idx(2));
                    if all(~isnan([startST, endST]))
                        delT(i) = (abs(endST - startST)) * frate;
                    end
                end
            end
        end

        % ---------- Method: Find # idx for each spout touch in terms of frames
        function [trialObj] = SpoutTouch (trialObj, potVarName, frate,msg)
            % First spout touch from bpod
            arguments
                trialObj    (1,:) Trial
                potVarName  (1,:) cell = {'Port1In','Port2In','Port1Out','Port2Out'} % Port1In = L onset; Port2In = R onset
                frate = 100
                msg = '-s'
            end
            
            touchIdx = cell(1,numel(trialObj)); % each cell contains the n structure of touch ID   
            
            for i = 1:numel(trialObj)
                rawSt = trialObj(i).RawSpoutTouch;
                for j = 1:numel (potVarName)
                    if isfield(rawSt,potVarName{j}) && ~any(isnan(rawSt.(potVarName{j})))                 
                        ID = max(round (rawSt.(potVarName{j})*frate),1);
                        ID = min (ID , trialObj(i).numFrame);
                        touchIdx{i}.(potVarName{j}) = ID; 
                    end
                end
                trialObj(i).RawSpoutTouch = touchIdx{i}; % Replace the whole event variable with spout touch info; If no touch - empty
                if ~strcmp (msg,'-s') && isempty (touchIdx{i}) 
                    fprintf ('Trial #%d has no spout touch \n',i);
                end
            end
        end

        
    end
end