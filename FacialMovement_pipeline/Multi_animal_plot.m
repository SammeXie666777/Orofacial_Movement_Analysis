% Prompt the user to select multiple .fig files
[figFiles, figPath] = uigetfile('*.fig', 'Select Figure Files', 'MultiSelect', 'on');

% Check if the user canceled the file selection
if isequal(figFiles, 0)
    disp('No files were selected. Exiting script.');
    return;
end

% Ensure figFiles is a cell array, even if only one file is selected
if ischar(figFiles)
    figFiles = {figFiles};
end

% Initialize cell arrays to store data from all figures
all_x_data = {};
all_y_data = {};
all_y_error = {};
mouse_names = {};
all_x_labels = {}; % To store x-axis labels if they are strings

% Loop through each selected figure file
for i = 1:length(figFiles)
    % Construct the full file path
    figFullPath = fullfile(figPath, figFiles{i});
    
    % Open the figure invisibly
    figHandle = openfig(figFullPath, 'invisible');
    
    % Extract data from the figure
    errorbarHandles = findobj(figHandle, 'Type', 'errorbar');
    if ~isempty(errorbarHandles)
        % If errorbar objects are found
        x_data = get(errorbarHandles, 'XData');
        y_data = get(errorbarHandles, 'YData');
        y_error = get(errorbarHandles, 'YNegativeDelta');
    else
        % If no errorbar objects, find line objects
        lineHandles = findobj(figHandle, 'Type', 'line');
        x_data = get(lineHandles, 'XData');
        y_data = get(lineHandles, 'YData');
        y_error = zeros(size(y_data)); % No error bars
    end
    
    % Extract x-axis labels if they exist
    ax = get(figHandle, 'CurrentAxes');
    x_labels = get(ax, 'XTickLabel'); % Get x-axis labels (e.g., "Week 14")
    
    % Close the figure after extracting data
    close(figHandle);
    
    % Ensure data are in row vectors
    if iscell(x_data)
        x_data = cell2mat(x_data);
    end
    if iscell(y_data)
        y_data = cell2mat(y_data);
    end
    if iscell(y_error)
        y_error = cell2mat(y_error);
    end
    
    % Store data and x-axis labels in cell arrays
    all_x_data{i} = x_data;
    all_y_data{i} = y_data;
    all_y_error{i} = y_error;
    all_x_labels{i} = x_labels; % Store x-axis labels if available
    
    % Use the figure file name (without extension) as the mouse name
    [~, mouse_name, ~] = fileparts(figFiles{i});
    mouse_names{i} = mouse_name;
end

% Collect all unique x-axis labels across figures
combined_x_labels = {};  % Temporary array to store all x-labels
for i = 1:length(all_x_labels)
    combined_x_labels = [combined_x_labels; all_x_labels{i}];
end
unique_x_labels = unique(combined_x_labels);  % Get unique labels

% Initialize matrices to store aligned y and y_error data for plotting
aligned_y_data = NaN(length(unique_x_labels), length(figFiles));
aligned_y_error = NaN(length(unique_x_labels), length(figFiles));

% Align each mouse's data to the unified x-axis labels
for i = 1:length(figFiles)
    % Get the indices of the current mouse's x-labels in the unified x-labels
    [~, loc] = ismember(all_x_labels{i}, unique_x_labels);
    
    % Place y and y_error data at the correct indices
    aligned_y_data(loc, i) = all_y_data{i};
    aligned_y_error(loc, i) = all_y_error{i};
end

% Create a new figure for the "error cloud" plot
figure;
hold on;

% Define a set of colors for plotting
colorOrder = [
    0.2, 0.6, 1.0;  % Blue
    1.0, 0.4, 0.4;  % Red
    0.2, 0.8, 0.4   % Green
];

% Create a new figure for the plot
figure;
hold on;

% Plot each dataset with error bars and a thicker mean line
for i = 1:length(figFiles)
    % Define the mean and standard deviation for each dataset
    mean_y = aligned_y_data(:, i);
    std_y = aligned_y_error(:, i);
    
    % Plot the error bars for each data point
    errorbar(1:length(unique_x_labels), mean_y, std_y, 'o', ...
             'Color', colorOrder(i, :), 'CapSize', 3, 'LineWidth', 2, ...
             'DisplayName', mouse_names{i}); % Error bar with default thickness
    
    % Plot the mean line with thicker line width
    plot(1:length(unique_x_labels), mean_y, '-', 'Color', colorOrder(i, :), ...
         'LineWidth', 3, 'DisplayName', [mouse_names{i}, ' Mean']);
end

% Customize the plot
set(gca, 'XTick', 1:length(unique_x_labels), 'XTickLabel', unique_x_labels);
xlabel('Age (Weeks)', 'Interpreter', 'none','FontSize',13,'FontWeight','bold');  % Directly set Interpreter to noneylabel('Reaction Time (s)', 'Interpreter', 'none');
title('Reaction Time Comparison of Mice with Error Bars', 'Interpreter', 'none','FontSize',13,'FontWeight','bold');

% Set legend interpreter to none for each legend item
lgd = legend('Location', 'best',FontSize=13,FontWeight='bold');
set(lgd, 'Interpreter', 'none');

ylabel ('Reaction time (s)','FontSize',13,'FontWeight','bold')
grid on;
hold off;
%% 
%% Outcome

figFiles = uigetfile('.fig', "MultiSelect", "on");

% Create a new figure for the subplots
newFig = figure;

% Number of subplots
numSubplots = length(figFiles);
col = 3;
row = ceil(numSubplots / col); % Ensure the number of rows is an integer

newYLim = [0 1];

% Initialize a variable to store handles to the plotted data for the legend
legendPlots = [];
legendLabels = {};

for i = 1:numSubplots
    % Open the .fig file
    fig = openfig(figFiles{i}, 'invisible');
    
    % Get the axes from the opened figure
    oldAxes = findobj(fig, 'type', 'axes');
    
    % Create a new subplot in the new figure
    newAxes = subplot(row, col, i, 'Parent', newFig);
    
    % Copy the contents of the old axes to the new subplot axes
    plots = copyobj(allchild(oldAxes), newAxes);
    
    % Set the new axes properties to match the old ones
    newAxes.XLim = oldAxes.XLim;
    newAxes.YLim = newYLim; % Set the new YLim
    newAxes.XLabel.String = oldAxes.XLabel.String;
    newAxes.YLabel.String = oldAxes.YLabel.String;
    newAxes.Title.String = oldAxes.Title.String;
    
    % Preserve tick marks and tick labels
    newAxes.XTick = oldAxes.XTick;
    newAxes.XTickLabel = oldAxes.XTickLabel;
    newAxes.YTick = oldAxes.YTick;
    newAxes.YTickLabel = oldAxes.YTickLabel;

    set(newAxes, 'TickLabelInterpreter', 'none');
    newAxes.XLabel.Interpreter = 'none';
    newAxes.YLabel.Interpreter = 'none';
    newAxes.Title.Interpreter = 'none';
    newAxes.Title.FontSize = 13;
    % Collect handles to the plots and their labels for the first subplot only
    if i == 1
        legendPlots = plots;
        legendLabels = arrayfun(@(h) h.DisplayName, plots, 'UniformOutput', false);
    end
    
    % Close the old figure
    close(fig);
end

figureLegend = legend(legendPlots, legendLabels, 'Orientation', 'vertical');
set(figureLegend, 'FontSize', 12, 'Box', 'on', 'Position', [0.9, 0.1, 0.05, 0.8], 'ItemTokenSize', [10, 10]);

% Add a common title
sTitle = sgtitle('Reaching trial outcome for all three mice over time');
sTitle.FontSize = 18;



%% GEt stats: Reward Onset
mouse =  allData_IM140;
vdlist = mouse.vdlist;
%EventTrace = mouse.VideoData.Pupil.EventData.RewardOut;
EventTrace = mouse.VideoData.Pupil.EventData.SpoutTouch;

bpodObj = mouse.BpodData;
trialTypeName = {"Success"};
[ids,trials_idx] = getTrialIdx(bpodObj,trialTypeName);

event_processed = fieldnames (EventTrace);
pos = zeros(1,numel(event_processed));

for i = 1:numel(event_processed)
    parts = strsplit(event_processed{i},'_');
    parts = strcat(parts{3},'_',parts{4});
    pos(i) = find(cellfun(@(x) contains(x, parts), vdlist));
end

TrialIdx = trials_idx.(trialTypeName{:}) (pos);
%[IM140_pupil,~] =  orofacial_mouse.TrialTypeBasedStats(EventTrace,TrialIdx,'FaceMotion','Reaching','RewardOut',0);
[IM140_pupil,~] =  orofacial_mouse.TrialTypeBasedStats(EventTrace,TrialIdx,'FaceMotion','Reaching','SpoutTouch',0);

%% Combine 3 animals
% RewardOut.Results.IM136 = IM136_pupil;
% RewardOut.Results.IM138 = IM138_pupil;
RewardOut.Results.IM140 = IM140_pupil;

%%
% Spout.Results.IM136 = IM136_pupil;
% Spout.Results.IM138 = IM138_pupil;
Spout.Results.IM140 = IM140_pupil;

%%
%dateplt = {'20240603','20240617','20240627','20240705','20240722'};
Results = Spout.Results;
% Week = {'Week14','Week17','Week20','Week23','Week26'}; % For face
% idx = {[1,5,8,15,20],[1,5,8,15,19],[2,7,14,20,26]};
Week = {'Week14','Week17','Week21'}; 
idx = {[1,4,6],[1,2,4],[1,4,5]};
animalIDs = {'IM136','IM138','IM140'};
deltaTime = 3;
figure;

% Initialize a variable to store handles to the average traces for the legend
legendHandles = [];
legendLabels = {'IM136 (MitoPark)','IM138 (MitoPark)','IM140 (Control)'};

% Legend font size and box properties
legendFontSize = 12; % Adjust as needed
legendBoxPosition = [0.5, 0.01, 0.4, 0.05]; % Adjust as needed

for i = 1:numel(Week)
    %date = dateplt{i};
    subplot(1, numel(Week), i);
    for j = 1: numel (animalIDs) % two animal
        fieldn = fieldnames (Results.(animalIDs{j}));
        vdID = idx {j};
        name = fieldn(idx{j});
        eventAvg = Results.(animalIDs{j}).(name{i}).eventStats(1,:);
        eventSEM = Results.(animalIDs{j}).(name{i}).eventStats(2,:);
        tMark = linspace(-3, 3, length(eventAvg));
        
        % Plot the average trace
        p = plot(tMark, eventAvg, 'LineWidth', 1, 'Marker', '.');
        hold on;
        
        % Plot the SEM shade with a similar color to the average trace
        fill([tMark, fliplr(tMark)], ...
             [eventAvg + eventSEM, fliplr(eventAvg - eventSEM)], ...
             p.Color, 'FaceAlpha', 0.2, 'EdgeColor', 'none');
        
        % Collect handles to the average traces for the figure-wide legend
        if i == 1
            legendHandles = [legendHandles, p];
        end

        xlim([-deltaTime, deltaTime]);
    end
    
    % Add individual legend for each subplot
    subplotLegend = legend({'Avg Pupil Diameter', '±1 Standard Error'}, 'Location', 'best');
    ylim ([24,36])
    %ylim ([0,0.6])
    %subplotLegend = legend({'Avg FME', '±1 Standard Error'}, 'Location', 'best');
    set(subplotLegend, 'FontSize', legendFontSize, 'Box', 'on');
    
    numTicks = 11;
    xticks(linspace(-deltaTime, deltaTime, numTicks));
    xlabel('Event time (s)');
    ylabel('Smoothed pupil diameter (pixels)');
    title(Week{i}, 'FontSize', 12);
end

% Create a legend for the entire figure using the average trace handles
figureLegend = legend(legendHandles, legendLabels, 'Orientation', 'horizontal');
set(figureLegend, 'FontSize', legendFontSize, 'Box', 'on', 'Position', legendBoxPosition);

% Add a common title
sTitle = sgtitle('Pupil Diameter of three mice around first spout touch averaged across trials from five sessions', 'FontSize', 16);
%sTitle = sgtitle('FME of three mice around first spout touch averaged across trials from five sessions', 'FontSize', 16);
set(sTitle, 'FontSize', 18, 'FontWeight', 'bold');


hFig = gcf;  % Get the handle to the current figure

% Find the existing sgtitle
sTitle = findobj(hFig, 'Type', 'Axes', 'Tag', 'suptitle');

% Set the properties for the sgtitle
set(sTitle, 'FontSize', 18, 'FontWeight', 'bold');


%% 
vdobj = VideoReader('Basler_acA1920-150um__40003388__20240711_163926898.mp4');
img = read(vdobj, 1000);
figure
imshow(img)

% Draw the first rectangle with specified properties and position
h1 = drawrectangle('Position', [100, 100, 150, 150], 'Color', 'red', 'LineWidth', 3, 'Label', 'Face');

% Draw the second rectangle with specified properties and position
%h2 = drawrectangle('Position', [300, 200, 140, 110], 'Color', 'blue', 'LineWidth', 3, 'Label', 'Pupil');

%% 
vdobj2 = VideoReader('VideoAdjusted_MATLAB_IM136_x40003388_20240617_135205703_Pupil.mp4.avi');
img = read(vdobj2, 24000);
figure;
imshow(img)


