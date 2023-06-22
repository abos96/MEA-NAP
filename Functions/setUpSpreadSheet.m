% This script imports data about the recordings ("meta-data") from csv /
% excel files to the matlab variables

if strcmp(spreadsheet_file_type, 'excel')
    [num,txt,~] = xlsread(spreadsheet_filename,sheet,xlRange);
    ExpName = txt(:,1); % name of recording
    ExpGrp = txt(:,3); % name of experimental group
    ExpDIV = num(:,1); % DIV number
elseif strcmp(spreadsheet_file_type, 'csv')
    if Params.SpreedsheetFolder
        cd(Params.SpreedsheetFolder)
        opts = detectImportOptions(spreadsheet_filename);
        cd(HomeDir)
    else
        opts = detectImportOptions(spreadsheet_filename);
    end
    opts.Delimiter = ',';
    opts.VariableNamesLine = 1;
    opts.VariableTypes{1} = 'char';  % this should be the recoding file name
    opts.VariableTypes{2} = 'double';  % this should be the DIV
    opts.VariableTypes{3} = 'char'; % this should be Group 
    if length(opts.VariableNames) > 3
        opts.VariableTypes{4} = 'char'; % this should be Ground
    end 
    opts.DataLines = csvRange; % read the data in the range [StartRow EndRow]
    % csv_data = readtable(spreadsheet_filename, 'Delimiter','comma');

    if Params.SpreedsheetFolder
        cd(Params.SpreedsheetFolder)
        csv_data = readtable(spreadsheet_filename, opts);
        cd(HomeDir)
    else
        csv_data = readtable(spreadsheet_filename, opts);
    end
    ExpName =  csv_data{:, 1};
    ExpGrp = csv_data{:, 3};
    ExpDIV = csv_data{:, 2};

    Params.electrodesToGroundPerRecordingUseName = 1;  % use name (instead of index) to ground electrodes

    if sum(strcmp('Ground',csv_data.Properties.VariableNames))
        Params.electrodesToGroundPerRecording = csv_data.('Ground'); % this should be a 1 x N cell array 
        if ~iscell(Params.electrodesToGroundPerRecording)
            Params.electrodesToGroundPerRecording = {Params.electrodesToGroundPerRecording};
        end 
    else 
        Params.electrodesToGroundPerRecording = [];
    end 
end 