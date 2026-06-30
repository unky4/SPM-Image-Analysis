function [logFiles, subjectRuns] = bids_get_log_files(Settings)
%BIDS_GET_LOG_FILES Locate Presentation log files stored in a BIDS dataset.
%
%   [logFiles, subjectRuns] = bids_get_log_files(Settings)
%
%   Searches each BIDS subject folder for logs in:
%
%       sub-<label>/log/sub-<label>_run<run>.<ext>
%
%   where <ext> is Settings.log2stan.logExtension. The returned subjectRuns
%   cell array has two columns: subject label without the sub- prefix and run
%   number. The run number is used as the behavioural session column because
%   the original toolbox used "session" for task splits.
%
%   The function intentionally does not expose BIDS prefixes as settings. The
%   subject entity, log folder, and run token are resolved internally.

    assert(isfield(Settings, 'bids') && isfield(Settings.bids, 'root'), ...
           'BIDS log discovery requires Settings.bids.root.');
    assert(isfield(Settings, 'log2stan') && isfield(Settings.log2stan, 'logExtension'), ...
           'BIDS log discovery requires Settings.log2stan.logExtension.');

    bidsRoot = Settings.bids.root;
    ext = char(Settings.log2stan.logExtension);
    ext = regexprep(ext, '^\.', '');
    logFolderName = get_log_folder_name(Settings);
    subjects = bids_get_subjects(Settings);
    runs = get_bids_runs(Settings);

    logFiles = cell(0, 1);
    subjectRuns = cell(0, 2);

    for s = 1:numel(subjects)
        subjectLabel = char(subjects{s});
        subEntity = add_bids_prefix(subjectLabel, 'sub');
        logDir = fullfile(bidsRoot, subEntity, logFolderName);

        if ~isfolder(logDir)
            warning('No log folder found for %s: %s', subEntity, logDir);
            continue
        end

        for r = 1:numel(runs)
            runValue = runs(r);
            matches = find_log_for_run(logDir, subEntity, runValue, ext);
            if isempty(matches)
                error('No log file found for %s run %d in %s.', subEntity, runValue, logDir);
            elseif numel(matches) > 1
                error('Multiple log files found for %s run %d in %s.', subEntity, runValue, logDir);
            end

            logFiles{end+1, 1} = fullfile(matches(1).folder, matches(1).name); %#ok<AGROW>
            subjectRuns{end+1, 1} = subjectLabel; %#ok<AGROW>
            subjectRuns{end, 2} = r;
        end
    end

    assert(~isempty(logFiles), 'No BIDS log files were found in %s.', bidsRoot);
end

function matches = find_log_for_run(logDir, subEntity, runValue, ext)
%FIND_LOG_FOR_RUN Return the matching log file for one subject/run.
    runPlain = sprintf('run%d', runValue);
    runPadded = sprintf('run%02d', runValue);
    runBids = sprintf('run-%02d', runValue);
    patterns = { ...
        sprintf('%s_%s.%s', subEntity, runPlain, ext), ...
        sprintf('%s_%s.%s', subEntity, runPadded, ext), ...
        sprintf('%s_%s.%s', subEntity, runBids, ext)};

    matches = [];
    for i = 1:numel(patterns)
        thisMatch = dir(fullfile(logDir, patterns{i}));
        if ~isempty(thisMatch)
            matches = [matches; thisMatch]; %#ok<AGROW>
        end
    end
end

function runs = get_bids_runs(Settings)
%GET_BIDS_RUNS Return numeric BIDS run values from settings.
    if isfield(Settings.bids, 'runs') && ~isempty(Settings.bids.runs)
        runs = Settings.bids.runs;
    else
        runs = 1;
    end
    if iscell(runs)
        tmp = zeros(size(runs));
        for i = 1:numel(runs)
            if isnumeric(runs{i})
                tmp(i) = runs{i};
            else
                tmp(i) = str2double(runs{i});
            end
        end
        runs = tmp;
    end
    runs = double(runs(:)');
end

function name = get_log_folder_name(Settings)
%GET_LOG_FOLDER_NAME Return the subject-level log folder name.
    name = 'log';
    if isfield(Settings, 'log_pipeline') && isfield(Settings.log_pipeline, 'logs') && ...
            isfield(Settings.log_pipeline.logs, 'folder') && ~isempty(Settings.log_pipeline.logs.folder)
        name = Settings.log_pipeline.logs.folder;
    end
end

function value = add_bids_prefix(value, entityName)
%ADD_BIDS_PREFIX Add a BIDS entity prefix when needed.
    value = char(value);
    prefix = [entityName, '-'];
    if ~startsWith(value, prefix)
        value = [prefix, value];
    end
end
