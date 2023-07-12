% Process data from MEA recordings of 2D and 3D cultures
% created: RCFeord, May 2021
% authors: T Sit, RC Feord, AWE Dunn, J Chabros and other members of the Synaptic and Network Development (SAND) Group
%% USER INPUT REQUIRED FOR THIS SECTION
% in this section all modifiable parameters of the analysis are defined,
% no subsequent section requires user input
% Please refer to the documentation for guidance on parameter choice here:
% https://analysis-pipeline.readthedocs.io/en/latest/pipeline-steps.html#pipeline-settings
clear all
close all
clc
% Directories
HomeDir = 'C:\Users\aboschi\OneDrive - Fondazione Istituto Italiano Tecnologia\Documents\GitHub\MEA-NAP'; % Where the Aanlysis pipeline code is located

load("AnalysisSettings.mat")

% Plot settingsvalue
Params.figExt = {'.png', '.svg'};  % supported options are '.fig', '.png', and '.svg'
Params.fullSVG = 1;  % whether to insist svg even with plots with large number of elements
Params.showOneFig = 1;  % otherwise, 0 = pipeline shows plots as it runs, 1: supress plots

%% Paths 
% add all relevant folders to path
cd(HomeDir)
addpath(genpath('Functions'))
addpath('Images')

%% GUI / Tutorial mode settings 

Params.guiMode = 0;
if Params.guiMode == 1
    runGUImode
end 

%% END OF USER REQUIRED INPUT SECTION
% The rest of the MEApipeline.m runs automatically. Do not change after this line
% unless you are an expert user.
% Define output folder names
formatOut = 'ddmmmyyyy'; 
Params.Date = datestr(now,formatOut); 
clear formatOut




%% setup - additional setup
setUpSpreadSheet  % import metadata from spreadsheet
[~,Params.GrpNm] = findgroups(Params.ExpGrp);
[~,Params.DivNm] = findgroups(Params.ExpDIV);

biAdvancedSettings

% create output data folder if doesn't exist
CreateOutputFolders(HomeDir, Params.outputDataFolder, Params.Date, Params.GrpNm)

% Set up one figure handle to save all the figures
oneFigureHandle = NaN;
oneFigureHandle = checkOneFigureHandle(Params, oneFigureHandle);
    
% plot electrode layout 
plotElectrodeLayout(Params.outputDataFolder, Params, oneFigureHandle)

% export parameters to csv file
outputDataWDatePath = fullfile(Params.outputDataFolder, strcat('OutputData',Params.Date));
ParamsTableSavePath = fullfile(outputDataWDatePath, strcat('Parameters_',Params.Date,'.csv'));
writetable(struct2table(Params,'AsArray',true), ParamsTableSavePath)

% save metadata
metaDataSaveFolder = fullfile(outputDataWDatePath, 'ExperimentMatFiles');
for ExN = 1:length(Params.ExpName)
    Info.FN = Params.ExpName(ExN);
    Info.DIV = num2cell(Params.ExpDIV(ExN));
    Info.Grp = Params.ExpGrp(ExN);
    InfoSavePath = fullfile(metaDataSaveFolder, strcat(char(Info.FN),'_',Params.Date,'.mat'));
    save(InfoSavePath,'Info')
end

% create a random sample for checking the probabilistic thresholding
if Params.ProbThreshPlotChecks == 1
    Params.randRepCheckExN = randi([1 length(Params.ExpName)],1,Params.ProbThreshPlotChecksN);
    Params.randRepCheckLag = Params.FuncConLagval(randi([1 length(Params.FuncConLagval)],1,Params.ProbThreshPlotChecksN));
    Params.randRepCheckP = [Params.randRepCheckExN;Params.randRepCheckLag];
end

%% Step 1 - spike detection

if ((Params.priorAnalysis == 0) || (Params.runSpikeCheckOnPrevSpikeData)) && (Params.startAnalysisStep == 1) 

    if (Params.detectSpikes == 1) || (Params.runSpikeCheckOnPrevSpikeData)
        addpath(Params.rawData)
    else
        addpath(Params.spikeDetectedData)
    end
    
    savePath = fullfile(Params.outputDataFolder, ...
                        strcat('OutputData', Params.Date), ...
                        '1_SpikeDetection', '1A_SpikeDetectedData');
    
    % Run spike detection
    if Params.detectSpikes == 1
        batchDetectSpikes(Params.rawData, savePath, option, Params.ExpName, Params);
    end 
    
    % Specify where ExperimentMatFiles are stored
    experimentMatFileFolder = fullfile(Params.outputDataFolder, ...
           strcat('OutputData',Params.Date), 'ExperimentMatFiles');

    % Plot spike detection results 
    for  ExN = 1:length(Params.ExpName)
        
        if Params.runSpikeCheckOnPrevSpikeData
            spikeDetectedDataOutputFolder = spikeDetectedData;
        else
            spikeDetectedDataOutputFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData', Params.Date), '1_SpikeDetection', '1A_SpikeDetectedData'); 
        end 
        
        spikeFilePath = fullfile(spikeDetectedDataOutputFolder, strcat(char(Params.ExpName(ExN)),'_spikes.mat'));
        load(spikeFilePath,'spikeTimes','spikeDetectionResult','channels','spikeWaveforms')

        experimentMatFilePath = fullfile(experimentMatFileFolder, ...
            strcat(char(Params.ExpName(ExN)),'_',Params.Date,'.mat'));
        load(experimentMatFilePath,'Info')

        spikeDetectionCheckGrpFolder = fullfile(Params.outputDataFolder, ...
            strcat('OutputData',Params.Date), '1_SpikeDetection', '1B_SpikeDetectionChecks', char(Info.Grp));
        FN = char(Info.FN);
        spikeDetectionCheckFNFolder = fullfile(spikeDetectionCheckGrpFolder, FN);

        if ~isfolder(spikeDetectionCheckFNFolder)
            mkdir(spikeDetectionCheckFNFolder)
        end 

        plotSpikeDetectionChecks(spikeTimes, spikeDetectionResult, ...
            spikeWaveforms, Info, Params, spikeDetectionCheckFNFolder, oneFigureHandle)
        
        % Check whether there are no spikes at all in recording 
        checkIfAnySpikes(spikeTimes, Params.ExpName{ExN});

    end

end

%% Step 2 - neuronal activity
if Params.priorAnalysis==0 || Params.priorAnalysis==1 && Params.startAnalysisStep<3
    fprintf('Running step 2 of MEA-NAP: neuronal activity \n')
    % Format spike data
    experimentMatFolderPath = fullfile(Params.outputDataFolder, ...
        strcat('OutputData',Params.Date), 'ExperimentMatFiles');

    for  ExN = 1:length(Params.ExpName)
            
        experimentMatFname = strcat(char(Params.ExpName(ExN)),'_',Params.Date,'.mat'); 
        experimentMatFpath = fullfile(experimentMatFolderPath, experimentMatFname);
        load(experimentMatFpath, 'Info')

        % extract spike matrix, spikes times and associated info
        disp(char(Info.FN))

        if Params.priorAnalysis==1 && Params.startAnalysisStep==2
            spikeDetectedDataFolder = Params.spikeDetectedData;
        else
            if Params.detectSpikes == 1
                spikeDetectedDataFolder = fullfile(Params.outputDataFolder, ...
                    strcat('OutputData', Params.Date), '1_SpikeDetection', ...
                    '1A_SpikeDetectedData');
            else
                spikeDetectedDataFolder = Params.spikeDetectedData;
            end
        end

        [spikeMatrix,spikeTimes,Params,Info] = formatSpikeTimes(... 
            char(Info.FN), Params, Info, spikeDetectedDataFolder);

        % initial run-through to establish max values for scaling
        spikeFreqMax(ExN) = prctile((downSampleSum(full(spikeMatrix), Info.duration_s)),95,'all');
        
        infoFnFilePath = fullfile(experimentMatFolderPath, ...
                          strcat(char(Info.FN),'_',Params.Date,'.mat'));
        save(infoFnFilePath, 'Info', 'Params', 'spikeTimes', 'spikeMatrix')

        clear spikeTimes
    end

    % extract and plot neuronal activity
    
    % Set up one figure handle to save all the figures
    oneFigureHandle = NaN;
    oneFigureHandle = checkOneFigureHandle(Params, oneFigureHandle);

    disp('Electrophysiological properties')

    spikeFreqMax = max(spikeFreqMax);

    for  ExN = 1:length(Params.ExpName)
        
        experimentMatFname = strcat(char(Params.ExpName(ExN)),'_',Params.Date,'.mat'); 
        experimentMatFpath = fullfile(experimentMatFolderPath, experimentMatFname);
        load(experimentMatFpath,'Info','Params','spikeTimes','spikeMatrix');

        % get firing rates and burst characterisation
        Ephys = firingRatesBursts(spikeMatrix,Params,Info);
        
        idvNeuronalAnalysisGrpFolder = fullfile(Params.outputDataFolder, ...
            strcat('OutputData',Params.Date), '2_NeuronalActivity', ...
            '2A_IndividualNeuronalAnalysis', char(Info.Grp));
        
        if ~isfolder(idvNeuronalAnalysisGrpFolder)
            mkdir(idvNeuronalAnalysisGrpFolder)
        end 
        
        idvNeuronalAnalysisFNFolder = fullfile(idvNeuronalAnalysisGrpFolder, char(Info.FN));
        if ~isfolder(idvNeuronalAnalysisFNFolder)
            mkdir(idvNeuronalAnalysisFNFolder)
        end 

        % generate and save raster plot
        rasterPlot(char(Info.FN),spikeMatrix,Params,spikeFreqMax, idvNeuronalAnalysisFNFolder, oneFigureHandle)
        % electrode heat maps
        electrodeHeatMaps(char(Info.FN), spikeMatrix, Info.channels, ... 
            spikeFreqMax,Params, idvNeuronalAnalysisFNFolder, oneFigureHandle)
        % half violin plots
        firingRateElectrodeDistribution(char(Info.FN), Ephys, Params, ... 
            Info, idvNeuronalAnalysisFNFolder, oneFigureHandle)

        infoFnFilePath = fullfile(experimentMatFolderPath, ...
                          strcat(char(Info.FN),'_',Params.Date,'.mat'));
        save(infoFnFilePath,'Info','Params','spikeTimes','Ephys', '-v7.3')

        clear spikeTimes spikeMatrix

    end

    % create combined plots across groups/ages
    PlotEphysStats(Params.ExpName,Params,HomeDir, oneFigureHandle)
    saveEphysStats(Params.ExpName, Params, HomeDir)
    cd(HomeDir)

end


%% Step 3 - functional connectivity, generate adjacency matrices

if Params.priorAnalysis==0 || Params.priorAnalysis==1 && Params.startAnalysisStep<4

    disp('generating adjacency matrices')
    
    % Set up one figure handle to save all the figures
    oneFigureHandle = NaN;
    oneFigureHandle = checkOneFigureHandle(Params, oneFigureHandle);

    for  ExN = 1:length(Params.ExpName)

        if Params.priorAnalysis==1 && Params.startAnalysisStep==3
            priorAnalysisExpMatFolder = fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles');
            spikeDataFname = strcat(char(Params.ExpName(ExN)),'_',Params.priorAnalysisDate,'.mat');
            spikeDataFpath = fullfile(priorAnalysisExpMatFolder, spikeDataFname);
            load(spikeDataFpath, 'spikeTimes', 'Ephys', 'Info')
        else
            ExpMatFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date), 'ExperimentMatFiles');
            spikeDataFname = strcat(char(Params.ExpName(ExN)),'_',Params.Date,'.mat');
            spikeDataFpath = fullfile(ExpMatFolder, spikeDataFname);
            load(spikeDataFpath, 'Info', 'Params', 'spikeTimes', 'Ephys')
        end

        disp(char(Info.FN))

        adjMs = generateAdjMs(spikeTimes,ExN,Params,Info,HomeDir, oneFigureHandle);

        ExpMatFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date), 'ExperimentMatFiles');
        infoFnFname = strcat(char(Info.FN),'_',Params.Date,'.mat');
        infoFnFilePath = fullfile(ExpMatFolder, infoFnFname);
        save(infoFnFilePath, 'Info', 'Params', 'spikeTimes', 'Ephys', 'adjMs')
    end

end

%% Step 4 - network activity

if Params.priorAnalysis==0 || Params.priorAnalysis==1 && Params.startAnalysisStep<=4
    
    % Set up one figure handle to save all the figures
    oneFigureHandle = NaN;
    oneFigureHandle = checkOneFigureHandle(Params, oneFigureHandle);
    ExpName = Params.ExpName;
    for  ExN = 1:length(ExpName) 

        if Params.priorAnalysis==1 && Params.startAnalysisStep==4
            priorAnalysisExpMatFolder = fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles');
            spikeDataFname = strcat(char(ExpName(ExN)),'_',Params.priorAnalysisDate,'.mat');
            spikeDataFpath = fullfile(priorAnalysisExpMatFolder, spikeDataFname);
            load(spikeDataFpath, 'spikeTimes', 'Ephys','adjMs','Info')
        else
            ExpMatFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date), 'ExperimentMatFiles');
            spikeDataFname = strcat(char(ExpName(ExN)),'_',Params.Date,'.mat');
            spikeDataFpath = fullfile(ExpMatFolder, spikeDataFname);
            load(spikeDataFpath, 'Info', 'Params', 'spikeTimes', 'Ephys','adjMs')
        end

        disp(char(Info.FN))
        
        idvNetworkAnalysisGrpFolder = fullfile(Params.outputDataFolder, ...
            strcat('OutputData',Params.Date), '4_NetworkActivity', ...
            '4A_IndividualNetworkAnalysis', char(Info.Grp));
        
        idvNetworkAnalysisFNFolder = fullfile(idvNetworkAnalysisGrpFolder, char(Info.FN));
        if ~isfolder(idvNetworkAnalysisFNFolder)
            mkdir(idvNetworkAnalysisFNFolder)
        end 
        
        if Params.priorAnalysis == 1
            if isempty(Params.spikeDetectedData)
                spikeDetectedDataFolder = fullfile(Params.outputDataFolder, ...
                    strcat('OutputData', Params.Date), '1_SpikeDetection', ...
                    '1A_SpikeDetectedData');
            else 
                spikeDetectedDataFolder = Params.spikeDetectedData;
            end 
        else
            spikeDetectedDataFolder = fullfile(Params.outputDataFolder, ...
                    strcat('OutputData', Params.Date), '1_SpikeDetection', ...
                    '1A_SpikeDetectedData');
        end 

        [spikeMatrix, spikeTimes, Params, Info] = formatSpikeTimes(char(Info.FN), ...
            Params, Info, spikeDetectedDataFolder);

        Params.networkActivityFolder = idvNetworkAnalysisFNFolder;

        NetMet = ExtractNetMet(adjMs, spikeTimes, ...
            Params.FuncConLagval, Info,HomeDir,Params, spikeMatrix, oneFigureHandle);

        ExpMatFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date), 'ExperimentMatFiles');
        infoFnFname = strcat(char(Info.FN),'_',Params.Date,'.mat');
        infoFnFilePath = fullfile(ExpMatFolder, infoFnFname);
        
        save(infoFnFilePath, 'Info', 'Params', 'spikeTimes', 'Ephys', 'adjMs','NetMet', '-append')

        clear adjMs

    end
    
    % save and export network data to spreadsheet
    saveNetMet(ExpName, Params, HomeDir)
    
    % Make network plots with shared colorbar and edge weight widths etc.
    outputDataDateFolder = fullfile(Params.outputDataFolder, ...
        strcat('OutputData', Params.Date));
    minMax = findMinMaxNetMetTable(outputDataDateFolder, Params);
    minMax.EW = [0.1, 1];
    Params.metricsMinMax = minMax;
    Params.useMinMaxBoundsForPlots = 1;
    Params.sideBySideBoundPlots = 1;
    
    for ExN = 1:length(ExpName) 
        disp(ExpName(ExN))
        % load NetMet 
        experimentMatFileFolder = fullfile(Params.outputDataFolder, ...
            strcat('OutputData', Params.Date), 'ExperimentMatFiles');
        experimentMatFilePath = fullfile(experimentMatFileFolder, ...
            strcat(char(ExpName(ExN)),'_',Params.Date,'.mat'));
        
        expData = load(experimentMatFilePath);
        idvNetworkAnalysisGrpFolder = fullfile(Params.outputDataFolder, ...
            strcat('OutputData',Params.Date), '4_NetworkActivity', ...
            '4A_IndividualNetworkAnalysis', char(expData.Info.Grp));
        
        idvNetworkAnalysisFNFolder = fullfile(idvNetworkAnalysisGrpFolder, char(expData.Info.FN));
        if ~isfolder(idvNetworkAnalysisFNFolder)
            mkdir(idvNetworkAnalysisFNFolder)
        end 
        
        Params.networkActivityFolder = idvNetworkAnalysisFNFolder;
            
        PlotIndvNetMet(expData, Params, expData.Info, oneFigureHandle)
        
        if Params.showOneFig
            clf(oneFigureHandle)
        else
            close all 
        end 
         
    end
    
    % create combined plots
    PlotNetMet(ExpName, Params, HomeDir, oneFigureHandle)
    
    if Params.includeNMFcomponents
        % Plot NMF 
        experimentMatFolder = fullfile(HomeDir, ...
            strcat('OutputData',Params.Date), 'ExperimentMatFiles');
        plotSaveFolder = fullfile(HomeDir, ...
            strcat('OutputData',Params.Date), '4_NetworkActivity', ...
            '4A_IndividualNetworkAnalysis');
        plotNMF(experimentMatFolder, plotSaveFolder, Params)
    end 
    
    % Set up one figure handle to save all the figures
    oneFigureHandle = NaN;
    oneFigureHandle = checkOneFigureHandle(Params, oneFigureHandle);


    
    % Aggregate all files and run density analysis to determine boundaries
    % for node cartography
    if Params.autoSetCartographyBoundaries
        usePriorNetMet = 0;  % set to 0 by default
        if Params.priorAnalysis==1 && usePriorNetMet
            experimentMatFileFolder = fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles');
            % cd(fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles'));   
            fig_folder = fullfile(Params.priorAnalysisPath, ...
                '4_NetworkActivity', '4B_GroupComparisons', '7_DensityLandscape');
        else
            experimentMatFileFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData', Params.Date), 'ExperimentMatFiles');
            % cd(fullfile(strcat('OutputData', Params.Date), 'ExperimentMatFiles'));  
            fig_folder = fullfile(Params.outputDataFolder, strcat('OutputData', Params.Date), ...
                '4_NetworkActivity', '4B_GroupComparisons', '7_DensityLandscape');
        end 
        
        if ~isfolder(fig_folder)
            mkdir(fig_folder)
        end 

        ExpList = dir(fullfile(experimentMatFileFolder, '*.mat'));
        add_fig_info = '';

        if Params.autoSetCartographyBoudariesPerLag
            for lag_val = Params.FuncConLagval
                [hubBoundaryWMdDeg, periPartCoef, proHubpartCoef, nonHubconnectorPartCoef, connectorHubPartCoef] = ...
                TrialLandscapeDensity(ExpList, fig_folder, add_fig_info, lag_val, oneFigureHandle);
                Params.(strcat('hubBoundaryWMdDeg', sprintf('_%.fmsLag', lag_val))) = hubBoundaryWMdDeg;
                Params.(strcat('periPartCoef', sprintf('_%.fmsLag', lag_val))) = periPartCoef;
                Params.(strcat('proHubpartCoef', sprintf('_%.fmsLag', lag_val))) = proHubpartCoef;
                Params.(strcat('nonHubconnectorPartCoef', sprintf('_%.fmsLag', lag_val))) = nonHubconnectorPartCoef;
                Params.(strcat('connectorHubPartCoef', sprintf('_%.fmsLag', lag_val))) = connectorHubPartCoef;
            end 

        else 
            lagValIdx = 1;
            [hubBoundaryWMdDeg, periPartCoef, proHubpartCoef, nonHubconnectorPartCoef, connectorHubPartCoef] = ...
                TrialLandscapeDensity(ExpList, fig_folder, add_fig_info, lag_val(lagValIdx), oneFigureHandle);
            Params.hubBoundaryWMdDeg = hubBoundaryWMdDeg;
            Params.periPartCoef = periPartCoef;
            Params.proHubpartCoef = proHubpartCoef;
            Params.nonHubconnectorPartCoef = nonHubconnectorPartCoef;
            Params.connectorHubPartCoef = connectorHubPartCoef;
        end 

        % save the newly set boundaries to the Params struct
        experimentMatFileFolderToSaveTo = fullfile(Params.outputDataFolder, ...
                strcat('OutputData', Params.Date), 'ExperimentMatFiles');
        for nFile = 1:length(ExpList)
            FN = ExpList(nFile).name;
            FNPath = fullfile(experimentMatFileFolderToSaveTo, FN);
            save(FNPath, 'Params', '-append')
        end 
       
        
    end 

    % Plot node cartography plots using either custom bounds or
    % automatically determined bounds
    for  ExN = 1:length(ExpName)

        if Params.priorAnalysis==1 && Params.startAnalysisStep==4 && usePriorNetMet
            experimentMatFileFolder = fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles');
            experimentMatFilePath = fullfile(experimentMatFileFolder, strcat(char(ExpName(ExN)),'_',Params.priorAnalysisDate,'.mat'));
            % TODO: load as struct rather than into workspace
            load(experimentMatFilePath, 'spikeTimes','Ephys','adjMs','Info', 'NetMet')
        else
            experimentMatFileFolder = fullfile(Params.outputDataFolder, strcat('OutputData', Params.Date), 'ExperimentMatFiles');
            experimentMatFilePath = fullfile(experimentMatFileFolder, strcat(char(ExpName(ExN)),'_',Params.Date,'.mat'));
            load(experimentMatFilePath,'Info','Params', 'spikeTimes','Ephys','adjMs', 'NetMet')
        end

        disp(char(Info.FN))

        fileNameFolder = fullfile(Params.outputDataFolder, strcat('OutputData',Params.Date), ...
                                  '4_NetworkActivity', '4A_IndividualNetworkAnalysis', ...
                                  char(Info.Grp), char(Info.FN));

        
        NetMet = plotNodeCartography(adjMs, Params, NetMet, Info, HomeDir, fileNameFolder, oneFigureHandle);
        % save NetMet now that we have node cartography data as well
        experimentMatFileFolderToSaveTo = fullfile(Params.outputDataFolder, strcat('OutputData', Params.Date), 'ExperimentMatFiles');
        experimentMatFilePathToSaveTo = fullfile(experimentMatFileFolderToSaveTo, strcat(char(Info.FN),'_',Params.Date,'.mat'));
        save(experimentMatFilePathToSaveTo,'Info','Params','spikeTimes','Ephys','adjMs','NetMet')
    end 
    
    % Plot node cartography metrics across all recordings 
    NetMetricsE = {'Dens','Q','nMod','Eglob','aN','CC','PL','SW','SWw', ... 
               'Hub3','Hub4', 'NCpn1','NCpn2','NCpn3','NCpn4','NCpn5','NCpn6'}; 
    NetMetricsC = {'ND','MEW','NS','Eloc','BC','PC','Z'};
    combinedData = combineExpNetworkData(ExpName, Params, NetMetricsE, ...
        NetMetricsC, HomeDir, experimentMatFileFolderToSaveTo);
    figFolder = fullfile(Params.outputDataFolder, strcat('OutputData', Params.Date), ...
        '4_NetworkActivity', '4B_GroupComparisons', '6_NodeCartographyByLag');
    plotNetMetNodeCartography(combinedData, ExpName,Params, HomeDir, figFolder, oneFigureHandle)
    

   

end

%% Optional step: Run density landscape to determine the boundaries for the node cartography 
if any(strcmp(Params.optionalStepsToRun,'getDensityLandscape')) 
    cd(fullfile(Params.priorAnalysisPath, 'ExperimentMatFiles'));
    
    fig_folder = fullfile(Params.priorAnalysisPath, '4_NetworkActivity', ...
        '4B_GroupComparisons', '7_DensityLandscape');
    if ~isfolder(fig_folder)
        mkdir(fig_folder)
    end 
    
    % loop through multiple DIVs
    for DIV = [14, 17, 21, 24, 28]
        ExpList = dir(sprintf('*DIV%.f*.mat', DIV));
        add_fig_info = strcat('DIV', num2str(DIV));
        [hubBoundaryWMdDeg, periPartCoef, proHubpartCoef, nonHubconnectorPartCoef, connectorHubPartCoef] ...
            = TrialLandscapeDensity(ExpList, fig_folder, add_fig_info, Params.cartographyLagVal);
    end 
end 

%% Optional step: statistics and classification of genotype / ages 
if any(strcmp(Params.optionalStepsToRun,'runStats'))
    if Params.showOneFig
        if ~isfield(Params, 'oneFigure')
            Params.oneFigure = figure;
        end 
    end 
    
    if Params.priorAnalysis 
        statsDataFolder = Params.priorAnalysisPath;
    else
        statsDataFolder = fullfile(Params.outputDataFolder, ...
                strcat('OutputData',Params.Date));
    end 
    
    nodeLevelFile = fullfile(statsDataFolder, 'NetworkActivity_NodeLevel.csv');
    nodeLevelData = readtable(nodeLevelFile);
    
    recordingLevelFile = fullfile(statsDataFolder, 'NetworkActivity_RecordingLevel.csv');
    recordingLevelData = readtable(recordingLevelFile);
    
    for lag_val = Params.FuncConLagval
        plotSaveFolder = fullfile(statsDataFolder, '5_Stats', sprintf('%.fmsLag', lag_val));
        if ~isfolder(plotSaveFolder)
            mkdir(plotSaveFolder)
        end 
        featureCorrelation(nodeLevelData, recordingLevelData, Params, lag_val, plotSaveFolder);
        doLDA(recordingLevelData, Params, lag_val);
        doClassification(recordingLevelData, Params, lag_val, plotSaveFolder);
    end 
end 

%% Optional step : combine plots across DIVs
if any(strcmp(Params.optionalStepsToRun,'combineDIVplots'))
    if Params.priorAnalysis == 1
        featureFolder = fullfile(Params.priorAnalysisPath, '4_NetworkActivity', '4A_IndividualNetworkAnalysis');
    else
        featureFolder = fullfile(Params.outputDataFolder, ['OutputData' Params.Date], '4_NetworkActivity', '4A_IndividualNetworkAnalysis');
    end 
    featureFolderSearch = dir(featureFolder);
    dirFlags = [featureFolderSearch.isdir];
    folderNames = {featureFolderSearch.name};
    groupFolders = folderNames(dirFlags);
    groupFolders = groupFolders(~ismember(groupFolders, {'.', '..'}));
    combinedPlotFolder = fullfile(Params.outputDataFolder, ['OutputData' Params.Date], ...
        '4_NetworkActivity', '4B_GroupComparisons', '8_CombinedPlotsByDiv');
    if 1 - isfolder(combinedPlotFolder)
        mkdir(combinedPlotFolder)
    end 
    
    for grpNameIdx = 1:length(Params.GrpNm)
        combinedPlotGroupFolder = fullfile(combinedPlotFolder, Params.GrpNm{grpNameIdx});
        if 1 - isfolder(combinedPlotGroupFolder)
            mkdir(combinedPlotGroupFolder)
        end 
    end 
    
    Params.includeIdvScaledPlotsInCombinedPlots = 1;
    Params.plotNames = {'3_scaled_MEA_NetworkPlotNodedegreeBetweenesscentrality.png', ...
                        '4_scaled_MEA_NetworkPlotNodedegreeParticipationcoefficient.png', ...
                        '5_scaled_MEA_NetworkPlotNodestrengthLocalefficiency.png', ...
                        '7_scaled_MEA_NetworkPlotNodedegreeAveragecontrollability.png', ... 
                        '8_scaled_MEA_NetworkPlotNodedegreeModalcontrollability.png', ...
                        '2_scaled_MEA_NetworkPlot.png', ...
                        };


    for nGroupFolder = 1:length(groupFolders)

        % get the recording folders 
        groupFolder = fullfile(featureFolder, groupFolders{nGroupFolder});
        groupFolderSearch = dir(groupFolder);
        dirFlags = [groupFolderSearch.isdir];
        folderNames = {groupFolderSearch.name};
        recordingFolders = folderNames(dirFlags);
        recordingFolders = recordingFolders(~ismember(recordingFolders, {'.', '..'}));

        % get the recording name excluding DIV 
        numRecordings = length(recordingFolders);
        recordingNames = cell(numRecordings, 1);
        for recordingIdx = 1:numRecordings
            recordingNameParts = split(recordingFolders{recordingIdx}, '_');
            recordingNames(recordingIdx) = join(recordingNameParts(1:end-1), '_');
        end 

        uniqueRecordings = unique(recordingNames);

        for uniqueRecordingIdx = 1:length(uniqueRecordings)

            recordingName = uniqueRecordings{uniqueRecordingIdx};
            recordingDIVfoldersSearch = dir(fullfile(groupFolder, sprintf('%s*', recordingName)));
            dirFlags = [recordingDIVfoldersSearch.isdir];
            recordingDIVfoldersSearchNames = {recordingDIVfoldersSearch.name};
            recordingDIVfolders = recordingDIVfoldersSearchNames(dirFlags);
            recordingDIVfolders = recordingDIVfolders(~ismember(recordingDIVfolders, {'.', '..'}));

            recordingDIVfolderFullPath = fullfile(groupFolder, recordingDIVfolders{1});
            recordingDIVfoldersSearch = dir(recordingDIVfolderFullPath);
            dirFlags = [recordingDIVfoldersSearch.isdir];
            recordingDIVfoldersSearchNames = {recordingDIVfoldersSearch.name};
            lagFolders = recordingDIVfoldersSearchNames(dirFlags);
            lagFolders = lagFolders(~ismember(lagFolders, {'.', '..'}));

            for lagIdx = 1:length(lagFolders)
                for plotNameIdx = 1:length(Params.plotNames)
                    % make the list of plot paths to combine
                    plotName = Params.plotNames{plotNameIdx};
                    plotPathsToCombine = cell(length(recordingDIVfolders), 1);

                    for divIdx = 1:length(recordingDIVfolders)
                        plotPathsToCombine{divIdx} = fullfile(...
                        groupFolder, recordingDIVfolders{divIdx}, ...
                        lagFolders{lagIdx}, plotName);
                    end 

                    % save the plot in 4B
                    outputFolder = fullfile(combinedPlotFolder, ...
                        groupFolders{nGroupFolder}, recordingName, ...
                        lagFolders{lagIdx});
                    if 1 - isdir(outputFolder)
                        mkdir(outputFolder)
                    end 
                    outputFilePath = fullfile(outputFolder,  plotName(1:end-4)); 
                    %  outputFilePath = fullfile(recordingDIVfolderFullPath, ... 
                    %     sprintf('combined_%s_%s', lagFolders{lagIdx}, plotName(1:end-4)));

                    combinePlots(plotPathsToCombine, outputFilePath, Params)

                end 
            end 

        end

    end
end

%% Optional Step: compare pre-post TTX spike activity 
if any(strcmp(Params.optionalStepsToRun,'comparePrePostTTX')) 
    % see find_best_spike_result.m for explanation of the parameters
    Params.prePostTTX.max_tolerable_spikes_in_TTX_abs = 100; 
    Params.prePostTTX.max_tolerable_spikes_in_grounded_abs = 100;
    Params.prePostTTX.max_tolerable_spikes_in_TTX_per_s = 1; 
    Params.prePostTTX.max_tolerable_spikes_in_grounded_per_s = 1;
    Params.prePostTTX.start_time = 0;
    Params.prePostTTX.default_end_time = 600;  
    Params.prePostTTX.sampling_rate = 1;  
    Params.prePostTTX.threshold_ground_electrode_name = 15;
    Params.prePostTTX.default_grounded_electrode_name = 15;
    Params.prePostTTX.min_spike_per_electrode_to_be_active = 0.5;
    Params.prePostTTX.wavelet_to_search = {'mea', 'bior1p5'};
    Params.prePostTTX.use_TTX_to_tune_L_param = 0;
    Params.prePostTTX.spike_time_unit = 'frame'; 
    Params.prePostTTX.custom_backup_param_to_use = []; 
    Params.prePostTTX.regularisation_param = 10;
    
    
    % Get spike detection result folder
    spike_folder = strcat(HomeDir,'/OutputData',Params.Date,'/1_SpikeDetection/1A_SpikeDetectedData/');
    spike_folder(strfind(spike_folder,'\'))='/';
    
    pre_post_ttx_plot_folder = fullfile(HomeDir, 'OutputData', ... 
        Params.Date, '1_SpikeDetection', '1C_prePostTTXcomparison'); 
    
    find_best_spike_result(spike_folder, pre_post_ttx_plot_folder, Params)
end 




