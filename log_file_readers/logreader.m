function loginfoPath = logreader(Info, logFilePath, outputPath)
% Reads a logfile, gets information for first level analysis and saves it
% as SPM12 readable matlab file
%
%   Inputs:
%       - Info: The info structure
%       - logFilePath: Path of the logfile that you are trying to read the
%                      info out of
%       - outputFodler: Path where we want to save the processed info from
%                       the logfile
%
%   Outputs:
%       - loginfoPath: The paths where we saved the processed info
    
    % Load the current subject log data (created by log2stan.m function)
    % Get also the index of the subject (used to know which column is
    % needed form the regressor csv file)
    logData = readtable(logFilePath);
    subjectNumber = findfirstincell(unique(logData.ID), Info.ID);
    logData = logData(strcmp(logData.ID, Info.ID), :);
    

    loginfoPath = struct();
    for ses = Info.Settings.startSession:Info.Settings.endSession
        % Get current seesion
        currentLogData = logData(logData.session == ses, :);

        % Get valid indicator
        isValid = logical(currentLogData.is_valid);
        if ~isempty(Info.firstLevelAnalysisSettings.extraIsValid)
            isValid = isValid & logical(currentLogData.(Info.firstLevelAnalysisSettings.extraIsValid));
        end

        logInfo = struct( ...
            'units', Info.firstLevelAnalysisSettings.units, ...
            'TR', Info.firstLevelAnalysisSettings.TR ...
        );

        % Get pmod
        if isfield(Info.firstLevelAnalysisSettings, 'pmod')
            pmod = Info.firstLevelAnalysisSettings.pmod;
            pmod.name = struct2cell(pmod.name);
            pmod.poly = struct2cell(pmod.poly);
            
            paramFolderPaths = struct2cell(Info.firstLevelAnalysisSettings.regressor_paths);
            paramPaths = cell(numel(paramFolderPaths), numel(pmod.name));
            for i = 1:numel(paramFolderPaths)
                for j = 1:numel(pmod.name)
                    paramPaths{i,j} = fullfile(paramFolderPaths{i}, [pmod.name{j}, '.mat']);
                end
            end
            % Construct the needed info for SPM12
            if ~isempty(paramFolderPaths{1})
                param = getstanparam(Info, paramPaths(:), subjectNumber);
                for i = 1:numel(param)
                    currentParam = table();
                    currentParam.param = param{i}(:);
                    currentParam.session = logData.session;
                    
                    pmod.param{i} = currentParam(currentParam.session == ses, :).param(isValid);
                end
            else
                for i = 1:numel(pmod.name)
                    pmod.param{i} = currentLogData.(pmod.name{i})(isValid);
                end
            end
    
            logInfo.pmod = pmod;
        end
        durations = currentLogData.durations(isValid);

        logInfo.names = struct2cell(Info.firstLevelAnalysisSettings.stanOnsetName);
        logInfo.contrasts = struct2cell(Info.firstLevelAnalysisSettings.contrasts);
        onsets = cell(size(logInfo.names));
        stanOnsetName = struct2cell(Info.firstLevelAnalysisSettings.stanOnsetName);
        for i = 1:numel(onsets)
            logInfo.onsets{i} = currentLogData.(stanOnsetName{i})(isValid);
        end
        logInfo.durations = {durations};
        %logInfo.outcomes = repelem({currentLogData.outcomes(isValid)}, numel(logInfo.names));
        %logInfo.reactionTimes = repelem({currentLogData.reaction_times(isValid)}, numel(logInfo.names));
        logInfo.orth = repelem(struct2cell(Info.firstLevelAnalysisSettings.ort), numel(logInfo.names));
        
        % Save
        outputName = fullfile(outputPath, [Info.ID, '_logdata_ses', num2str(ses), '.mat']);
        save(outputName, '-struct', 'logInfo');
        outputNamePaths = getpaths(outputName);
        for field = fields(outputNamePaths)'
            loginfoPath(ses).(field{1}) = outputNamePaths.(field{1});
        end
    end
end
