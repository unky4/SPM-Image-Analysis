function varargout = log2stan(logDir, varargin)
%LOG2STAN Convert Presentation log files into trial-wise modelling tables.
%
%   data = log2stan(logDir, 'settingsFilePath', settingsPath)
%   log2stan(logDir, 'settingsFilePath', settingsPath, 'outputDir', outputDir)
%
%   LOG2STAN reads Presentation .txt or .mat log files, extracts trial-level
%   behavioural variables, and returns or writes a CSV table suitable for
%   later Stan/RL modelling and image-analysis onset generation. LOGS2STAN is also available as a descriptive wrapper name.
%
%   Inputs:
%       - logDir: folder containing flat log files. Pass an empty value when
%                 log_pipeline.logs.source is "bids".
%
%   Input pairs (second value is the default value):
%
%       - 'settingsFilePath', 'settings.YAML':
%               Path to the YAML file containing the settings
%       - 'outputDir', '':
%               The optional path where output is saved
%       - 'fileName', 'data':
%               Name of the output file
%
%   Output
%       - varargout{1} : Converted log file. Must be present if there is
%                        no outputDir given.
    spmia_setup_paths(mfilename('fullpath'));
    if isstring(logDir) && isscalar(logDir)
        logDir = char(logDir);
    end

    % Parse input or get defualts
    InputArgs = parseinput('log2stan', varargin{:});

    % Load settings and convert some to cell
    Settings = getsettings(InputArgs.settingsFilePath);
    Settings.log2stan.Phrases.newSession = struct2cell(Settings.log2stan.Phrases.newSession);
    Settings.log2stan.Phrases.isInstrumental = struct2cell(Settings.log2stan.Phrases.isInstrumental);
    Settings.log2stan.Phrases.picturePresent = struct2cell(Settings.log2stan.Phrases.picturePresent);
    Settings.log2stan.Phrases.badTrial = struct2cell(Settings.log2stan.Phrases.badTrial);
    Settings.log2stan.displayName = struct2cell(Settings.log2stan.displayName);
    Settings.log2stan.displayNameInd = struct2cell(Settings.log2stan.displayNameInd);
    Settings.log2stan.groupByNames = struct2cell(Settings.log2stan.groupByNames);
    Settings.log2stan.feedbacks = struct2cell(Settings.log2stan.feedbacks);
    Settings.log2stan.reinforcements = struct2cell(Settings.log2stan.reinforcements);


    % Get the log files. BIDS log discovery is used when requested in the
    % pipeline settings; otherwise the original flat-folder behaviour is used.
    if should_use_bids_logs(Settings)
        [logFiles, subjectIDs] = bids_get_log_files(Settings);
    else
        [logFiles, subjectIDs] = get_flat_log_files(logDir, Settings);
    end

    
    data = table();
    trialID = 1;
    for i = 1:numel(logFiles)
        if i > 1 && ~strcmp(subjectIDs{i, 1}, subjectIDs{i-1, 1})
            trialID = 1;
        end
        % Get the log file in a partitioned (by task) cell array
        [partitionedLog, Inds] = getpartitionedcelllog(logFiles{i}, Settings.log2stan.Phrases.newSession, Settings.log2stan.timeScaler, true);
        
        trialIDSes = 1;
        for trialInd = 1:numel(partitionedLog)
            % Note reinforcements = outcomes, it is just easier to store
            % twice
            trialData = struct( ...
                'ID', string(subjectIDs{i, 1}), ...
                'session', subjectIDs{i, 2}, ...
                'trial_ID', trialID, ...
                'trial_ID_by_ses', trialIDSes, ...
                'trial_type', "", ...
                'trial_type_number', 0, ...
                'choices', 0, ...
                'reinforcements', 0, ...
                'is_valid', 0, ...
                'is_instrumental', 0, ...
                'reaction_times', 0, ...
                'onsets_outcome', 0, ...
                'onsets_buttonpress', 0, ...
                'onsets_pics_presentation', 0, ...
                'durations', 0, ...
                'outcomes', 0 ...
            );
            [trialData, isSkipLine] = gettrialdata(trialData, partitionedLog{trialInd}, Settings, Inds);
            if ~isSkipLine
                data = [data; struct2table(trialData)];
                
                trialIDSes = trialIDSes + 1;
                trialID = trialID + 1;
            end
        end
    end

    % Save overall data
    if strcmp(InputArgs.outputDir, '')
        varargout{1} = data;
    else
        writetable(data, fullfile(InputArgs.outputDir, [InputArgs.fileName, '.csv']));
    end
end


function tf = should_use_bids_logs(Settings)
%SHOULD_USE_BIDS_LOGS True when logs should be discovered from BIDS folders.
    tf = false;
    if isfield(Settings, 'log_pipeline') && isfield(Settings.log_pipeline, 'logs') && ...
            isfield(Settings.log_pipeline.logs, 'source')
        tf = strcmpi(Settings.log_pipeline.logs.source, 'bids');
    end
end

function [logFiles, subjectIDs] = get_flat_log_files(logDir, Settings)
%GET_FLAT_LOG_FILES Locate logs in a single folder using the legacy layout.
    assert(~isempty(logDir), 'A log directory is required when BIDS log discovery is disabled.');
    files = dir(logDir);
    files = {files.name}';
    logFiles = cell(0, 1);
    subjectIDs = cell(0, 2);
    for i = 1:numel(files)
        if strcmp(files{i}, '.') || strcmp(files{i}, '..')
            continue;
        end
        [~, name, ext] = fileparts(files{i});
        if strcmp(ext, ['.', Settings.log2stan.logExtension])
            logFiles{end+1, 1} = fullfile(logDir, files{i}); %#ok<AGROW>
            if isempty(Settings.sessionSuffix)
                subjectIDs{end+1, 1} = name; %#ok<AGROW>
                subjectIDs{end, 2} = 1;
            else
                subjectIDs{end+1, 1} = regexprep(name, [Settings.sessionSuffix, '[0-9]*'], ''); %#ok<AGROW>
                subjectIDs{end, 2} = regexprep(name, [subjectIDs{end, 1}, Settings.sessionSuffix], '');
            end
        end
    end
end


function [trialData, isSkipLine] = gettrialdata(trialData, trialBlock, Settings, Inds)
% Appends the required data from a trial block to the trialData
%   
    
    % Get which trial is this from the names
    nameInd = -1;
    for i = 1:length(Settings.log2stan.groupByNames)
        if isdatacontains(trialBlock(1,:), Settings.log2stan.groupByNames{i})
            nameInd = i;
            break;
        end
    end
    
    % Filter when the response was not in the name list
    isSkipLine = false;
    if nameInd == -1
        warning(['The response was not in the name list. ' ...
                 'Only important if you want to include all trials. ' ...
                 'Hence, you may need to expand your name list ' ...
                 '(groupByNames) or may need to include another word in: ' ...
                 'Phrases.badTrial.'])
        isSkipLine = true;
        return
    end

    % Filter bad trial
    if isdatacontains(trialBlock, Settings.log2stan.Phrases.badTrial)
        return
    end

    % Filter no response
    responseHumanInd = findfirstincell(trialBlock(:, Inds.eventType), 'Response');
    if isempty(responseHumanInd)
        return
    end
    if isempty(trialBlock{responseHumanInd, Inds.code})
        return
    end
    
    % Filter trials when subject pressed the button before they were alowed
    % to
    if isempty(Settings.log2stan.Phrases.picturePresent)
        picturePresentInd = 1;
    else
        picturePresentInd = findfirstincell(trialBlock(:, Inds.code), Settings.log2stan.Phrases.picturePresent);
    end
    if responseHumanInd <= picturePresentInd
        return
    end

    % End of exception handling, except for reaction time


    % Get choice
    choice = trialBlock{responseHumanInd, Inds.code};
    orderIndicators = fieldnames(Settings.log2stan.OrderIndicators);
    for i = 1:numel(orderIndicators)
        if isdatacontains(trialBlock(1,:), orderIndicators{i})
            choice = Settings.log2stan.OrderIndicators.(orderIndicators{i})(choice);
            continue
        end
    end
    
    % Get feedbacks and reinforcements for current trial
    isCurrentGroupByNamesNeeded = cell2mat(cellfun(@(x) strcmp(x, Settings.log2stan.groupByNames{nameInd}), Settings.log2stan.groupByNames, 'UniformOutput', false));
    currentFeedbacks = cell(size(isCurrentGroupByNamesNeeded));
    currentReinforcements = cell(size(isCurrentGroupByNamesNeeded));
    for i = 1:numel(isCurrentGroupByNamesNeeded)
        if (isCurrentGroupByNamesNeeded(i))
            currentFeedbacks{i} = Settings.log2stan.feedbacks{i};
            currentReinforcements{i} = Settings.log2stan.reinforcements{i};
        end
    end
    currentFeedbacks = currentFeedbacks(~cellfun('isempty', currentFeedbacks));
    currentReinforcements = currentReinforcements(~cellfun('isempty', currentReinforcements));

    % Get onset times (ButtonPress and PiicsPresentation)
    onsetsButtonpress = trialBlock{responseHumanInd, Inds.time};
    onsetsPicsPresentation = trialBlock{picturePresentInd, Inds.time};

    % Filter trials when response time is greater than allowed
    responseTime = onsetsButtonpress - onsetsPicsPresentation;
    if responseTime >= Settings.log2stan.maxResponseTime || responseTime <= Settings.log2stan.minResponseTime
        return
    end

    % Get onset times (Outcome)
    onsetsOutcome = trialBlock{findfirstincell(trialBlock(:, Inds.code), currentFeedbacks), Inds.time};

    % Decide whther instrumental trial
    is_instrumental = findfirstincell(trialBlock(:, Inds.code), Settings.log2stan.Phrases.isInstrumental);
    if isempty(is_instrumental)
        is_instrumental = 0;
    end

    % Fill in the trialData
    trialData.trial_type = string(Settings.log2stan.displayName{nameInd});
    trialData.trial_type_number = Settings.log2stan.displayNameInd{nameInd};
    trialData.choices = choice;
    trialData.reinforcements = currentReinforcements{findfirstincell(currentFeedbacks, trialBlock{findfirstincell(trialBlock(:, Inds.code), currentFeedbacks), Inds.code})};
    trialData.is_valid = 1;
    trialData.is_instrumental = is_instrumental;
    trialData.reaction_times = responseTime;
    trialData.onsets_outcome = onsetsOutcome;
    trialData.onsets_buttonpress = onsetsButtonpress;
    trialData.onsets_pics_presentation = onsetsPicsPresentation;
    trialData.durations = 0;
    trialData.outcomes = trialData.reinforcements;
end
