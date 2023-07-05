function [] = CreateOutputFolders(HomeDir, OutputDataFolder, Date, GrpNm)
% this function creates the following output folder structure:
%
%   OutputData+Date
%       ExperimentMatFiles
%       1_SpikeDetection
%       2_NeuronalActivity
%       3_EdgeThresholdingCheck
%       4_NetworkActivity
% Parameters
% ----------
% HomeDir : 
% OutputDataFolder : 
% Date : 
% GrpNm : 
% Returns 
% -------
% None

%% make sure we start in the home directory
cd(OutputDataFolder)

%% does an output folder already exist for that date?

if isfolder(strcat('OutputData',Date))
    % if so, choose a suffix to rename previous analysis folder
    NewFNsuffix = inputdlg({'An output data folder already exists for the date today, enter a suffix for the old folder to differentiate (i.e. v1)'});
    NewFN = strcat('OutputData',Date,char(NewFNsuffix));
    % rename the old folder
    if isfolder(strcat('OutputData',Date)) 
         movefile(strcat('OutputData',Date),NewFN)
    else 
        error('origin or destination folder does not exist')
    end
end

%% now we can create the output folders
% TODO: remove cd from all of these
outputDataDateFolder = fullfile(OutputDataFolder, strcat('OutputData', Date));
spikeDetectionFolder = fullfile(outputDataDateFolder, '1_SpikeDetection');

neuronalActivityFolder = fullfile(outputDataDateFolder, '2_NeuronalActivity');

mkdir(strcat('OutputData',Date))
cd(strcat('OutputData',Date))
mkdir('ExperimentMatFiles')
mkdir('1_SpikeDetection')
cd('1_SpikeDetection')
mkdir('1A_SpikeDetectedData')
mkdir('1B_SpikeDetectionChecks')
cd('1B_SpikeDetectionChecks')
for i = 1:length(GrpNm)
    mkdir(char(GrpNm{i}))
end
cd(OutputDataFolder); cd(strcat('OutputData',Date));
mkdir('2_NeuronalActivity')
cd('2_NeuronalActivity')
mkdir('2A_IndividualNeuronalAnalysis')
cd('2A_IndividualNeuronalAnalysis')
for i = 1:length(GrpNm)
    mkdir(char(GrpNm{i}))
end
cd(OutputDataFolder); cd(strcat('OutputData',Date)); cd('2_NeuronalActivity')
mkdir('2B_GroupComparisons')
cd('2B_GroupComparisons')
mkdir('1_NodeByGroup')
mkdir('2_NodeByAge')
mkdir('3_RecordingsByGroup')
cd('3_RecordingsByGroup')
mkdir('HalfViolinPlots')
mkdir('NotBoxPlots')
cd(OutputDataFolder); cd(strcat('OutputData',Date)); 
cd('2_NeuronalActivity'); cd('2B_GroupComparisons')
mkdir('4_RecordingsByAge')
cd('4_RecordingsByAge')
mkdir('HalfViolinPlots')
mkdir('NotBoxPlots')
cd(OutputDataFolder)
cd(strcat('OutputData',Date))
mkdir('3_EdgeThresholdingCheck')
mkdir('4_NetworkActivity')
cd('4_NetworkActivity')
mkdir('4A_IndividualNetworkAnalysis')
cd('4A_IndividualNetworkAnalysis')
for i = 1:length(GrpNm)
    mkdir(char(GrpNm{i}))
end
cd(OutputDataFolder); cd(strcat('OutputData',Date)); cd('4_NetworkActivity')
mkdir('4B_GroupComparisons')
cd('4B_GroupComparisons')
mkdir('1_NodeByGroup')
mkdir('2_NodeByAge')
mkdir('3_RecordingsByGroup')
cd('3_RecordingsByGroup')
mkdir('HalfViolinPlots')
mkdir('NotBoxPlots')
cd(OutputDataFolder); cd(strcat('OutputData',Date)); 
cd('4_NetworkActivity'); cd('4B_GroupComparisons')
mkdir('4_RecordingsByAge')
cd('4_RecordingsByAge')
mkdir('HalfViolinPlots')
mkdir('NotBoxPlots')
cd(OutputDataFolder); cd(strcat('OutputData',Date)); 
cd('4_NetworkActivity'); cd('4B_GroupComparisons')
mkdir('5_GraphMetricsByLag')
mkdir('6_NodeCartographyByLag')
cd(HomeDir)
addpath(genpath(fullfile(OutputDataFolder, strcat('OutputData',Date))))

end