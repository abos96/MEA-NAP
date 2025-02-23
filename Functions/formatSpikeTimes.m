function [spikeMatrix,spikeTimes,Params,Info] = formatSpikeTimes(File, Params, Info, spikeDataFolder)

% this function loads in the spike detection result and creates a
% spike matrix and spike times structure for the chosen spike detection
% method and chosen length of recording

% Parameters
% -----------
% File : character
%    name of the recording, excluding file extensions
% Params : structure
%    here we will use Params.SpikesCostParam, Params.SpikesMethod,
%    Params.TruncRec and Params.TruncLength
% Info : structure
% spikeDataFolder : path to directory 
%     absolute path to the folder containing the spike detected files
% Returns 
% -------
% spikeMatrix : matrix 
% spikeTimes : struct 
% Params : struct 
% Info : struct 
%   Info.channels : vector 
%       list of electrode names
%    


%% load spike detection result

fileName = strcat(char(File),'_spikes.mat');
fileFullPath = fullfile(spikeDataFolder, fileName);

% try
load(fileFullPath, 'spikeTimes', 'spikeDetectionResult', 'channels')
% remove empty channels
spikeTimes = spikeTimes(~cellfun(@isempty, spikeTimes));
% catch
%     load(strcat(char(File),'.mat'),'spikeTimes','spikeDetectionResult','channels')
%     % remove empty channels
%     spikeTimes = spikeTimes(~cellfun(@isempty, spikeTimes));
% end

Info.channels = channels;

% 2022-10-07 : Temp hack to remove electrode 82 if 59 electrodes were used
% with the MCS60 layout, in the future there should be manual specification
% of which electrodes as "missing" from the standard layout, or ideally
% none at all 

if strcmp(Params.channelLayout, 'MCS60') && length(spikeTimes) == 59
    fprintf('Detected 59 electrodes with MCS60 layout, removing electrode 82 \n')
    inclusionIndex = find(channels ~= 82);
    Info.channels = channels(inclusionIndex);
    Params.coords = Params.coords(inclusionIndex, :);
end 


%% merge spikes if using multiple spike detection methods

if strcmp(Params.SpikesMethod,'merged') || strcmp(Params.SpikesMethod,'mergedAll')
    for uu = 1:length(spikeTimes)
        [spike_times{uu}.('mergedAll'),~, ~] = mergeSpikes(spikeTimes{uu}, 'all');
    end
    clear spikeTimes
    spikeTimes = spike_times;
elseif strcmp(Params.SpikesMethod,'mergedWavelet')
    for uu = 1:length(spikeTimes)
            [spike_times{uu}.('mergedWavelet'),~, ~] = mergeSpikes(spikeTimes{uu}, 'wavelets');
    end
    clear spikeTimes
    spikeTimes = spike_times;
end

%% format full length or truncated recording

if Params.TruncRec == 0
    Info.duration_s = floor(spikeDetectionResult.params.duration);
end

% truncate spike times
if Params.TruncRec == 1
    for uu = 1:length(spikeTimes)
        temp_spike_times = double(spikeTimes{1,uu}.(Params.SpikesMethod));
        temp_spike_times(temp_spike_times>Params.TruncLength) = [];
        spikeTimes{1,uu}.(Params.SpikesMethod) = [];
        spikeTimes{1,uu}.(Params.SpikesMethod) = temp_spike_times;
        clear temp_spike_times
    end
    if spikeDetectionResult.params.duration < Params.TruncLength
        Info.duration_s = spikeDetectionResult.params.duration;
    else
        Info.duration_s = Params.TruncLength;
    end
end

Params.fs = spikeDetectionResult.params.fs;

%% create spike matrix

spikeMatrix = SpikeTimesToMatrix(spikeTimes,spikeDetectionResult,Params.SpikesMethod,Info);
while  floor(length(spikeMatrix)/Params.fs)~=Info.duration_s
    n2del = Params.fs*(length(spikeMatrix)/Params.fs - floor(length(spikeMatrix)/Params.fs));
    spikeMatrix=spikeMatrix(1:length(spikeMatrix)-(n2del),:);
end

% make into sparse matrix to reduce size of variable
spikeMatrix = sparse(spikeMatrix);

end