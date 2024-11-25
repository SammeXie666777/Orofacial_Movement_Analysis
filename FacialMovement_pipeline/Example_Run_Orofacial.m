% Example useage of orofacial_mouse classdef

%%%%% Define orofacial_mouse obj and get bpod
IM140 =  orofacial_mouse('IM140','Control');
mouse = allData_IM140;
disp('Start to get video...')
getVideo(mouse)
%%
disp('Start to get bpod directory...')
getBpod(mouse)
%%
disp('Start to craate bpod objs...')
defBpod(mouse)
%%
displayMappings(mouse.PairObj.VdBpodPairObj) % Display videos and bpod
%%%% !!!!! Several videos are cut at the end; Figre out a way to either
%%%% trim bpod or video
%% 
disp('Get period of interest from bpod...')
[mouse,eventIdx] = getTrialIdx(mouse,'LRRewardChoice',[-3,3],1); % eventIdx for all trials
[mouse, RewardRec_Idx] = getTrialIdx(mouse,'PostRewardPeriod',[-3,3],1); % eventIdx for all trials


%%%%%%%%%%%%%%%% Pupil %%%%%%%%%%%%%%%%%%%%
%% Pupil and event alignment 

[rawData,mouse] = getPupil(mouse,0.5,"median_dist",0);
%% Find processed video
vdlist = mouse.vdlist;
rawData = mouse.VideoData.Pupil.RawData;
pupil_processed = fieldnames (rawData);
pos = zeros(1,numel(pupil_processed));

for i = 1:numel(pupil_processed)
    parts = strsplit(pupil_processed{i},'_');
    parts = strcat(parts{3},'_',parts{4});
    pos(i) = find(cellfun(@(x) contains(x, parts), vdlist));
end

%tempIdx = eventIdx(pos);
tempIdx = RewardRec_Idx(pos);

%% Align pupil traces with event data 
filteredData = mouse.VideoData.Pupil.RawData;
[EventTrace,parsed] = orofacial_mouse.AlignRawWithEvent (filteredData,tempIdx,"Pupil","FilteredTrace",1);
mouse.VideoData.Pupil.EventData.ParsedTrialDataAll = parsed;
%mouse.VideoData.Pupil.EventData.RewardOut = EventTrace;
mouse.VideoData.Pupil.EventData.SpoutTouch = EventTrace;

%% 
bpodObj = mouse.BpodData;
trialTypeName = {"Success"};
[ids,trials_idx] = getTrialIdx(bpodObj,trialTypeName);
TrialIdx = trials_idx.(trialTypeName{:}) (pos);
%%
[Stats,~] = orofacial_mouse.TrialTypeBasedStats(EventTrace,TrialIdx,"Pupil","Reaching","SpoutTouch");
%% 
%save(strcat('%s_NoReachTrials_EventData',mouse.mouseID,'.mat'),'EventTrace','Stats','ids','trials_idx');
% Plot video with pupil traces
orofacial_mouse.AlignVdTrace(parsed,tempIdx,TrialIdx,"NoReachTrial",10)  

   
%%%%%%%%%%%%%%%% Face Motion %%%%%%%%%%%%%%%%%%%%

%% Face Motion
vdlist = mouse.vdlist; % Should input vdlist for whaever we need to process, 
gamma = ones(size(vdlist)); % 0708/0711 gamma = 0.6
id = dispVdID (mouse,{'20240708','20240711'});
gamma (1,cell2mat(id)) = 0.6;
%% 
lengths= cellfun(@(innerCell) cellfun(@length, innerCell), eventIdx, 'UniformOutput', false);
faceStats = getFaceMotion(mouse,vdlist,lengths,gamma) ;     

%% Index processed videos
rawData = mouse.VideoData.FaceMotion.RawData;

vdlist = mouse.vdlist;
face_processed = fieldnames (rawData);
pos = zeros(1,numel(face_processed));

for i = 1:numel(face_processed)
    parts = strsplit(face_processed{i},'_');
    parts = strcat(parts{3},'_',parts{4});
    pos(i) = find(cellfun(@(x) contains(x, parts), vdlist));
end

%tempIdx = eventIdx(pos);
tempIdx = RewardRec_Idx(pos);

%% Event_aligned traces and avergaed traces
[EventTrace] = orofacial_mouse.AlignRawWithEvent (rawData,tempIdx,'FaceMotion');
mouse.VideoData.FaceMotion.EventData.SpoutTouch = EventTrace;
%mouse.VideoData.FaceMotion.EventData.RewardOut3secOnset = EventTrace;

%%
bpodObj = mouse.BpodData;
trialTypeName = {"Success"};
[ids,trials_idx] = getTrialIdx(bpodObj,trialTypeName);


pos = zeros(1,numel(event_processed));

for i = 1:numel(event_processed)
    parts = strsplit(event_processed{i},'_');
    parts = strcat(parts{3},'_',parts{4});
    pos(i) = find(cellfun(@(x) contains(x, parts), vdlist));
end

TrialIdx = trials_idx.(trialTypeName{:}) (pos);
eventData = mouse.VideoData.FaceMotion.EventData.SpoutTouch;
event_processed = fieldnames (eventData);
%%
%[Stats,idx] =  orofacial_mouse.TrialTypeBasedStats(EventTrace,TrialIdx,'FaceMotion','Reaching','RewardOut');
[Stats,idx] =  orofacial_mouse.TrialTypeBasedStats(EventTrace,TrialIdx,'FaceMotion','Reaching','SpoutTouch');

 %%

orofacial_mouse.displayMotion(movObj, 'trial', face_stats.ROI, wholeTrialdata, startFrame, EventIdx)  


%% Results from Bpod: plotting
[mapping,IM136Results] = plotTrialOutcome (mouse);



%% PCA
[AllTraces, labels] = orofacial_mouse.combineAllTraces (mouse.VideoData.FaceMotion.EventData.RewardOnset3sec, {'IM136'});
