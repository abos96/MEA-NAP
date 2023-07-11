% Use this script to convert raw data collected with the Axion Maestro MEA system
% from plate to individual MEAs.  This is the first step to using the data with our 
% analysis pipeline developed for MCS data.
%
% Function written by MH, Dec 2021; edited by SM, Jan 2022
%

% Overall aim of this script is to split raw data from multi-well plate
% into a separate .mat file for each MEA in the plate.  It can currently
% accommodate 6- up to 48-well plates.  
% Function written by MH, Dec 2021; edited by SM, Jan 2022

% Overall aim of this script is to split raw data from multi-well plate
% into a separate .mat file for each MEA in the plate.  It can currently
% accommodate 6- up to 48-well plates.  

% Step 1 - Load the folder where your .raw data files are from plate to individual MEAs.  This is the first step to using the data with our 
% analysis pipeline developed for MCS data. Please include appropriate slash (/ or \) at the end of your path. 
dirname = 'D:\20230208 NGN2 Mono\';

% Step 2 - Loop through all of the files.  This first part extracts the names of the
% raw data files, arrangement of the wells and creates a .csv file with the
% file names for use downstream in the network analysis pipeline.
filenames = dir(dirname);
rownames = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];

% The line below creates the .csv file for the network analysis pipeline.
% You can name this file whatever is relevant for your experiment.
metadatafilename = '20230208_NGN2_Mono.csv';

%Please answer the following questions to determine which information the
%output file (metadatafilename) will be automatically filled with

fill_div='y'; %Did user write age groups in the following format (DIV4, DIV7, DIV10, etc.)? ('y' for yes, 'n' for no)
fill_genotype='y'; %Did user only use one genotype group when recording? ('y' for yes, 'n' for no) 
genotype='WT'; %If user answered no for fill_genotype, leave as empty string (''). Otherwise, enter your genotype group as a string.  

assert((isequal(fill_div,'y') | isequal(fill_div, 'n')), 'User did not select valid option for fill_div (y for yes or n for no).')
assert(isequal(fill_genotype,'y') | isequal(fill_genotype, 'n'), 'User did not select valid option for fill_genotype (y for yes or n for no).')

if isequal(fill_genotype, 'n') 
    assert(isequal(genotype,'') && isa(genotype, 'char'), 'User should leave genotype as empty string ('')')
elseif isequal (fill_genotype, 'y')
    assert(isa (genotype, 'char') , 'User did not enter valid option for genotype.')
end

% This line opens the .csv with the names in order to create three columns
% that are read by the network analysis pipeline.
for i=1:length(filenames)
    if length(filenames(i).name)>4
        suffix = filenames(i).name(end-3:end);
        if suffix=='.raw'
            % For each recording, this step loads the raw data calling a
            % function from the AxIS MATLAB Files folder
            AllData=AxisFile(strcat(dirname, filenames(i).name)).RawVoltageData.LoadData;
            % For each recording, this step loops over the wells to extra
            % the voltage vectors. Again this uses functions from the AxIS
            % MATLAB File folder
            for j1=1:size(AllData, 1)
                for j2=1:size(AllData, 2)
                    temp=[AllData{j1,j2,:,:}];
                    dat=temp.GetVoltageVector;
                    % For each individual MEA (well), this step saves the 
                    % voltage vector along with two variables used in the
                    % network analysis pipeline as an .mat file with the
                    % suffix indicating the well number (e.g., _A1).
                    savenamefile = strcat(dirname, filenames(i).name(1:end-4), '_', rownames(j1), int2str(j2), '.mat');
                    channels = 1;
                    % This creates a channels variable with the names of
                    % the 60 electrodes for an MEA in a 6-well plate.
                    if size(AllData, 1)*size(AllData, 2)==6
                        channels = [11:18, 21:28, 31:38, 41:48, 51:58, 61:68, 71:78, 81:88];
                    % This creates a channels variable with the names of
                    % the 16 electrodes for an MEA in a 48-well plate.
                    end
                    if size(AllData, 1)*size(AllData, 2)==48
                        channels = [11:14, 21:24, 31:34, 41:44];
                    else
                        warning('You need to manually add the channels variable for your plate configuration.')
                    end
                    % This is hard coded for MEA recording acquisition rate (fs) 
                    % of 12500 Hz. Change if data was acquired at a different rate.
                    fs = 12500; 
                    % This is the step saves the .mat file for each MEA
                    % (well) with voltage vectors (dat), the names/location
                    % of the electrodes (channels) and  the acquisition rate (fs). 
                    % Setting MATLAB version "-v7.3" appears necessary for saving.
                    save(savenamefile, '-v7.3', "dat", "channels", "fs")
                end
               end
            % This step adds filename without the suffix to the list for
            % batch analysis.
        end
    
    end
end
fillBatchFile (dirname,metadatafilename,fill_div,fill_genotype,genotype) 

% The next step is to run the .mat file outputs through the network
% analysis pipeline starting with the spike detection (Step 1).