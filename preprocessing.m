function preprocessing(varargin)
% Performes the preprocessing of fMRI scans.
%
%   Input pairs (second value is the default value):
%
%       - 'settingsFilePath', 'settings.YAML':
%               Path to the YAML file containing the settings
%
%       - 'jobFunction', 'preprocessing_job':
%               SPM12 preprocessing job function name (without .m)
%               To create one see the default custom
%               preprocessing_job function.
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
%       - preprocessing()
%               - Uses all default values
%
%       - preprocessing('settingsFilePath', 'custom_settings.YAML', ...
%                       'jobFunction', 'custom_preprocessing_job', ...
%                       'nofNodesToUse', 4, ...
%                       'nodeID', 2)
%               - Uses the settings located in the custom_settings.YAML file
%               - Uses the preprocessing function called
%                 custom_preprocessing_job
%               - Splits the data between 4 nodes
%               - Runs the preprocessing on the 2nd node
    
    spmia_setup_paths(mfilename('fullpath'));

    % Parse input or get defualts
    InputArgs = parseinput('preprocessing', varargin{:});


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

    
    % Run the preprocessing
    preprocessing_(subjectIDs, Settings, InputArgs.jobFunction);
end


function preprocessing_(subjectIDs, Settings, jobFunction)
% The main preprocessing code
%

    % Loop through each subject
    for subjInd = 1:numel(subjectIDs)
        % Get current patient ID and skip if empty
        subjectID = subjectIDs{subjInd};
        if isempty(subjectID)
            continue;
        end
        
        try
            preprocessingsubject(subjectID, Settings, jobFunction)
        catch eMsg
            fprintf(1,'Identifier: %s\n', eMsg.identifier);
            fprintf(1,'Message: %s\n', eMsg.message);
            fprintf(1,'In file: %s\n', eMsg.stack.name);
            fprintf(1,'In line: %d\n', eMsg.stack.line);
        end
    end
end


function preprocessingsubject(subjectID, Settings, jobFunction)
% Preprocessing for one subjectstartSes

    % Initialise/Load Info structure where we save most analyis related
    % information
    Info = getinfo(subjectID, Settings);
    
    
    % Create save folder
    createdir(Info.paths.preprocessingSave.fullPath)
    
    
    % Loop through the sessions
    for ses = Info.Settings.startSession:Info.Settings.endSession
        Info = preprocessingsession(ses, Info, Settings, jobFunction);
    end
    
    
    % Save the (updated) Info of the current subject
    save(Info.paths.pathsSave.fullPath, '-struct', 'Info');
end


function Info = preprocessingsession(ses, Info, Settings, jobFunction)
% Preprocessing for one session
    % Get the full paths and file parts of the data and save paths.
    % BIDS is used when enabled; otherwise the flat-folder layout is used.
    if isfield(Settings, 'bids') && isfield(Settings.bids, 'enabled') && Settings.bids.enabled
        Info.paths.functionalNii(ses) = getpaths(bids_get_func_nii(Settings, Info.ID, ses));
    elseif Info.Settings.nofSessions > 1
        Info.paths.functionalNii(ses) = getpaths(fullfile(Settings.functionalPath, [Info.ID, Settings.functionalSuffix, Settings.sessionSuffix, num2str(ses), '.nii']));
    else
        Info.paths.functionalNii(ses) = getpaths(fullfile(Settings.functionalPath, [Info.ID, Settings.functionalSuffix, '.nii']));
    end

    % Copy NIfTI files to the preprocessing folder. SPM generally expects
    % uncompressed .nii files, so .nii.gz files are unzipped after copying.
    copiedPath = fullfile(Info.paths.preprocessingSave.fullPath, [Info.paths.functionalNii(ses).name, Info.paths.functionalNii(ses).ext]);
    copyfile(Info.paths.functionalNii(ses).fullPath, Info.paths.preprocessingSave.fullPath);
    if endsWith(copiedPath, '.gz')
        gunzip(copiedPath, Info.paths.preprocessingSave.fullPath);
        delete(copiedPath);
        copiedPath = erase(copiedPath, '.gz');
    end

    % Update the path to the copied working file.
    Info.paths.functionalNii(ses) = getpaths(copiedPath);
     
    % Get the number of slices in the funcional image file
    niftiInfo = niftiinfo(Info.paths.functionalNii(ses).fullPath);
    if length(niftiInfo.ImageSize) == 3
        Info.nofSlices(ses) = 1;
    else
        Info.nofSlices(ses) = niftiInfo.ImageSize(end);
    end


    % Get current files in the save folder
    originalSavePath = Info.paths.preprocessingSave.fullPath;
    prevFiles = dir(originalSavePath);
    
    
    % Get all the source files
    sourceFiles = cell(Info.nofSlices(ses) - Info.Settings.nofSlicesToDiscard, 1);
    for i = 1:length(sourceFiles)
        sourceFiles{i} = [Info.paths.functionalNii(ses).fullPath, ',', num2str(i+Info.Settings.nofSlicesToDiscard)];
    end

    % Get spm job
    matlabbatch = jobFunction(Info, sourceFiles);

    % Run
    done = false;
    nofFails = 0;
    while ~done && nofFails < 10
        try
            spm_jobman('initcfg')
            spm_jobman('run', matlabbatch);
            done = true;
        catch
            deletefailedfiles(prevFiles, originalSavePath)
            nofFails = nofFails + 1;
            continue;
        end
    end
    
    % New files
    Info = moveandsavenewfilepaths(Info, ses, prevFiles, originalSavePath, 'preprocessing');
end

function deletefailedfiles(prevFiles, originalSavePath)
    prevFiles = {prevFiles.name}';
    prevFiles = prevFiles(~ismember(prevFiles, {'.', '..'}));

    currFiles = dir(originalSavePath);
    currFiles = {currFiles.name}';
    currFiles = currFiles(~ismember(currFiles, {'.', '..'}));
    
    newFiles = currFiles(~ismember(currFiles, prevFiles));

    for i = 1:numel(newFiles)
        delete(fullfile(originalSavePath, newFiles{i}));
    end
end