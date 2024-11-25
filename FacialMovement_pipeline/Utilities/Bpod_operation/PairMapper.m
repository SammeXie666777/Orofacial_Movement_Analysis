classdef PairMapper < handle
    % Map Outcome or TrialType
    properties
        OutcomesToID
    end
    
    methods
        function obj = PairMapper()
            obj.OutcomesToID = containers.Map('KeyType', 'char', 'ValueType', 'any');
            %obj.displayMappings();  % Display mappings when the object is created
        end
        
        function OutComePairobj = addMapping(OutComePairobj, outcomes, ids)
            % Main method: add outcomes - id pairs
            arguments
                OutComePairobj PairMapper
                outcomes (1,:) cell  
                ids (1,:) cell
            end

            if length(outcomes) ~= length(ids)
                error('The number of outcomes must match the number of IDs.');
            end
            
            for i = 1:length(outcomes)
                outcome = outcomes{i};
                id = ids{i};
                
                if ~ischar(outcome) || isstring(outcome) 
                    outcome = char(outcome); % Ensure outcome is a char
                end
                
                if isKey(OutComePairobj.OutcomesToID, outcome)
                    % If the outcome already exists, append the new ID to the list
                    existingIDs = OutComePairobj.OutcomesToID(outcome);
                    OutComePairobj.OutcomesToID(outcome) = [existingIDs, {id}];
                else
                    % Otherwise, create a new entry with the ID in a cell array
                    OutComePairobj.OutcomesToID(outcome) = {id};
                end
            end

            OutComePairobj.displayMappings();
        end
        
        function ids = getID(obj, outcome)
            % Retrieve the IDs corresponding to a given outcome
            if isKey(obj.OutcomesToID, outcome)
                ids = obj.OutcomesToID(outcome);
            else
                error('The specified outcome is not mapped to any ID.');
            end
        end

        function outcome = getOutcome(obj, id, displayOption)
            % Retrieve the outcome corresponding to a given ID with an option to display it
            arguments
                obj PairMapper
                id  cell
                displayOption logical = true  % Default is not to display
            end
            keys = obj.OutcomesToID.keys;
            values = obj.OutcomesToID.values;
            
            outcome = {};
            for i = 1:length(keys)
                if any(cellfun(@(x) any(cellfun(@(y) isequal(x, y), values{i})), id))
                    outcome = [outcome, keys{i}];  % Append outcome if ID is found
                end
            end            
            if isempty(outcome)
                warning('The specified ID is not mapped to any outcome.');
            end            
            if displayOption
                idStrArray = cellfun(@(x) num2str(x), id, 'UniformOutput', false);
                fprintf('ID(s): %s are mapped to the following outcome(s):\n', strjoin(idStrArray, ', '));                
                for i = 1:length(outcome)
                    fprintf('%s\n', outcome{i});
                end
            end
        end
        
        function displayMappings(obj)
            % Display all outcome-ID mappings
            disp('Outcome to ID mappings:');
            keys = obj.OutcomesToID.keys;
            values = obj.OutcomesToID.values;
            for i = 1:length(keys)
                fprintf('Outcome: %s, IDs: %s\n', keys{i}, strjoin(cellfun(@mat2str, values{i}, 'UniformOutput', false), ', '));
            end
        end
        
        function [outcomes, ids] = getMappings(obj)
            % Retrieve all outcome-ID mappings
            outcomes = obj.OutcomesToID.keys;
            ids = obj.OutcomesToID.values;
        end
    end
end
