function Info = getinfo(subjectID, Settings)
% Initialise/Load Info structure where we save most analyis related info
%
%   Inputs:
%       - subjectID: ID of a subject
%       - Settings: The settings structure loaded from the JSON file
%                   See getsettings.m function
%
%   Outputs:
%       - Info: The initialised info structure
%

    % Define the paths save location
    pathsFilePath = fullfile(Settings.saveRoot, 'paths', [subjectID, '_paths.mat']);
    
    
    % Load the path structure (where we store the paths for each
    % created file during the analysis) or if it does not exist
    % initialise it
    if exist(pathsFilePath, 'file') == 2
        Info = load(pathsFilePath);
        
        % Check whether root is the same in the info file as the
        % pathsFilePath. If not change it and save it
        Info = changeroot(Info, Settings);
        save(Info.paths.pathsSave.fullPath, '-struct', 'Info');
    else
        % Initialise
        Info = struct();
        Info.Settings = Settings;
        Info.paths.SPM = getpaths(Settings.spmPath);
        Info.paths.originalData = getpaths(Settings.functionalPath);
        Info.paths.saveRoot = getpaths(Settings.saveRoot);
        Info.paths.preprocessingSave = getpaths(fullfile(Settings.saveRoot, 'preprocessing', subjectID));
        Info.paths.firstlaSave = getpaths(fullfile(Settings.saveRoot, 'first_level', subjectID));
        Info.paths.secondlaSave = getpaths(fullfile(Settings.saveRoot, 'files_for_second_level'));
        Info.paths.pathsSave = getpaths(pathsFilePath);
        Info.ID = subjectID;
        
        % Create folder where we will save path files
        mkdir(Info.paths.pathsSave.path);
    end
end