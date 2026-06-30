function firstlevelanalysis(varargin)
% Performes the first levelan alysis of fMRI scans.
%
%   Input pairs (second value is the default value):
%
%       - 'settingsFilePath', 'settings.YAML':
%               Path to the YAML file containing the settings
%
%       - 'logFileReaderFunction', 'logreader':
%               Function name to load the info from a log file
%               To create one see the default custom readlog function. 
%
%       - 'jobFunction', 'firstlevelanalysis_job':
%               SPM12 firstlevelanalysis job function name (without .m)
%               To create one see the default custom
%               firstlevelanalysis_job function.
%
%       - 'nofNodesToUse', 1:
%               Number of partitions that we want to devide the full
%               dataset
%               Note: This is useful when you want to do this on
%                     the cluster with multiple nodes.
%               Example: Let's say you have 2 nodes and 1000 
%                        patients data. Then you can divide the
%                        1000 patients into 2 groups (500 each)
%                        and do 500 patients on one node and do
%                        the other 500 on the other node
%
%       - 'nodeID', 1:
%               Which part to do in the partition.
%               Must be: 1 <= nodeID <= nofNodesToUse
%               Example: Let's say you have again 2 node and divide
%                        the patients equally between the 2 nodes.
%                        When you call this main function with the
%                        qsub command then you esentially need to
%                        submit 2 seperate jobs. For the first job
%                        nodeID = 1 and for the second nodeID = 2.
%
%   Usage:
%       - firstlevelanalysis()
%               - Uses all default values
%
%       - firstlevelanalysis('settingsFilePath', 'custom_settings.YAML', ...
%                            'logFileReaderFunction', 'custom_log_reader', ...
%                            'jobFunction', 'custom_firstlevelanalysis_job', ...
%                            'nofNodesToUse', 4, ...
%                            'nodeID', 2)
%               - Uses the settings located in the custom_settings.YAML file
%               - Uses the log reader function called
%                 custom_log_reader
%               - Uses the firstlevelanalysis function called
%                 custom_firstlevelanalysis_job
%               - Splits the data between 4 nodes
%               - Runs the first-level analysis on the 2nd node
    
    spmia_setup_paths(mfilename('fullpath'));

    % Parse input or get defualts
    InputArgs = parseinput('firstlevelanalysis', varargin{:});


    % Load settings
    Settings = getsettings(InputArgs.settingsFilePath);

    % Start SPM12
    if ~isempty(Settings.spmPath)
        addpath(Settings.spmPath);
        addpath(fullfile(Settings.spmPath, 'matlabbatch'));
    end
    global defaults
    spm('Defaults', 'fMRI');
    defaults.stats.resmem = Settings.resmem;
    defaults.stats.maxmem = 5000000000;

    
    % Get subject IDs for the current node/group
    subjectIDs = getsubjects(Settings, InputArgs.nofNodesToUse, InputArgs.nodeID);

    
    % Run the firstlevelanalysis
    firstlevelanalysis_(subjectIDs, Settings, InputArgs.logFileReaderFunction, InputArgs.jobFunction);
end


function firstlevelanalysis_(subjectIDs, Settings, logFileReaderFunction, jobFunction)
% The main first-level analysis code
%

    % Loop through each subject
    for subjInd = 1:numel(subjectIDs)
        % Get current patient ID and skip if empty
        subjectID = subjectIDs{subjInd};
        if isempty(subjectID)
            continue;
        end
        
        try
            firstlevelanalysissubject(subjectID, Settings, logFileReaderFunction, jobFunction)
        catch eMsg
            fprintf(1,'Identifier: %s\n', eMsg.identifier);
            fprintf(1,'Message: %s\n', eMsg.message);
            fprintf(1,'In file: %s\n', eMsg.stack.name);
            fprintf(1,'In line: %d\n', eMsg.stack.line);
        end
    end
end


function firstlevelanalysissubject(subjectID, Settings, logFileReaderFunction, jobFunction)
% First-level analysis for one subject

    % Initialise/Load Info structure where we save most analyis related
    % information
    Info = getinfo(subjectID, Settings);
    
    % Run
    done = false;
    nofFails = 0;
    while ~done && nofFails < 10
        if nofFails > 0
            rmdir(Info.paths.firstlaSave.fullPath, 's');
        end

        try
            % Create save folder
            createdir(Info.paths.firstlaSave.fullPath)
            
            
            % Save first level analysis settings
            Info.firstLevelAnalysisSettings = Settings.first_level_analysis;
            
        
            % Read and save 
            Info.paths.loginfo = logFileReaderFunction(Info, Info.firstLevelAnalysisSettings.data_path, Info.paths.firstlaSave.fullPath);
        
            
            % Get current files in the save folder
            originalSavePath = Info.paths.firstlaSave.fullPath;
            prevFiles = dir(originalSavePath);
            
            
            % Get all the source files
            sourceFiles = cell(Info.Settings.endSession, 1);
            for ses = Info.Settings.startSession:Info.Settings.endSession
                sourceFiles{ses} = cell(Info.nofSlices(ses)-Info.Settings.nofSlicesToDiscard, 1);
                for i = 1:length(sourceFiles{ses})
                    sourceFiles{ses}{i} = [Info.paths.preprocessingFile_swr(ses).fullPath, ',', num2str(i+Info.Settings.nofSlicesToDiscard)];
                end
            end
        
            
            % Get spm job
            matlabbatch = jobFunction(Info, sourceFiles);
    

    
            spm_jobman('initcfg')
            spm_jobman('run', matlabbatch);
            done = true;
        catch
            %deletefailedfiles(prevFiles, originalSavePath)
            nofFails = nofFails + 1;
            continue;
        end
    end
    
    
    % New files
    Info = moveandsavenewfilepaths(Info, 1, prevFiles, originalSavePath, 'firstla');

    
    
    % Save the (updated) Info of the current subject
    save(Info.paths.pathsSave.fullPath, '-struct', 'Info');
end