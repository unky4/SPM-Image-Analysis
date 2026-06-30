function functionalPath = bids_get_func_nii(Settings, subjectID, runIndex)
%BIDS_GET_FUNC_NII Locate one functional NIfTI file in a BIDS-like dataset.
%
%   functionalPath = bids_get_func_nii(Settings, subjectID, runIndex)
%
%   Returns the functional image for one subject and one internally requested
%   run. The public settings file lists the repeated task acquisitions as
%   Settings.bids.runs, for example:
%
%       bids.runs = [1 2]
%
%   The original code still loops over internal session indices 1..N. This
%   function maps each internal index to the corresponding value in
%   Settings.bids.runs and returns exactly one NIfTI path for that run.
%
%   Supported functional filename styles
%   -----------------------------------
%   1. Standard BIDS run entity, for example:
%          sub-001_task-pain_run-01_bold.nii
%
%   2. Task label contains the run number, for datasets where the long task
%      was split into acquisitions named as separate task labels, for example:
%          sub-001_task-run1_bold.nii
%          sub-001_task-run2_bold.nii
%
%      In this style, resting-state files such as sub-001_task-rest_bold.nii
%      are automatically ignored because the function searches specifically
%      for task-run<runNumber>.
%
%   Optional Settings.bids.space, Settings.bids.desc, and Settings.bids.session
%   fields can be used only when a dataset contains several derivative files
%   that otherwise match the same subject/run.

    bids = Settings.bids;
    subLabel = add_bids_entity_prefix(subjectID, 'sub');
    suffix = get_optional_bids_value(bids, 'suffix', 'bold');
    runValue = resolve_requested_run_value(bids, runIndex);
    runEntityLabels = make_bids_run_entity_labels(runValue);
    taskRunLabels = make_task_run_labels(runValue);

    funcDirs = resolve_bids_func_dirs(bids.root, subLabel, bids);

    allMatches = [];
    usedPatterns = {};
    for d = 1:numel(funcDirs)
        funcDir = funcDirs(d).path;
        sesLabel = funcDirs(d).session_label;

        patterns = build_bids_func_patterns(subLabel, sesLabel, runEntityLabels, taskRunLabels, suffix, bids);
        for i = 1:numel(patterns)
            candidateMatches = find_matching_nii(funcDir, patterns{i});
            if ~isempty(candidateMatches)
                allMatches = [allMatches; candidateMatches]; %#ok<AGROW>
                usedPatterns{end+1} = fullfile(funcDir, patterns{i}); %#ok<AGROW>

                % Patterns are ordered from most specific to broadest. Once a
                % pattern matches inside a func directory, do not continue to
                % broader patterns for that same directory because that would
                % reintroduce ambiguous files such as task-rest.
                break
            end
        end
    end

    allMatches = unique_dir_results(allMatches);

    if isempty(allMatches)
        error(['No BIDS functional image matched subject %s and run index %d ', ...
               '(requested run value %s) in %s. Expected either a standard ', ...
               'BIDS run entity such as *_run-01_%s.nii or a task-run label ', ...
               'such as *_task-run1_%s.nii.'], ...
               subLabel, runIndex, run_value_to_char(runValue), bids.root, suffix, suffix);
    elseif numel(allMatches) > 1
        error(['Multiple BIDS functional images matched subject %s and run index %d ', ...
               '(requested run value %s). Matched patterns included %s. ', ...
               'Set bids.space, bids.desc, or bids.session more specifically.'], ...
               subLabel, runIndex, run_value_to_char(runValue), strjoin(usedPatterns, '; '));
    end

    functionalPath = fullfile(allMatches(1).folder, allMatches(1).name);
end

function matches = find_matching_nii(funcDir, pattern)
%FIND_MATCHING_NII Return .nii and .nii.gz files for one glob pattern.
    matches = [dir(fullfile(funcDir, [pattern, '.nii'])); ...
               dir(fullfile(funcDir, [pattern, '.nii.gz']))];
    matches = matches(~[matches.isdir]);
end

function matches = unique_dir_results(matches)
%UNIQUE_DIR_RESULTS Remove duplicate dir results while preserving order.
    if isempty(matches)
        return
    end
    fullNames = arrayfun(@(x) fullfile(x.folder, x.name), matches, 'UniformOutput', false);
    [~, keepIdx] = unique(fullNames, 'stable');
    matches = matches(keepIdx);
end

function patterns = build_bids_func_patterns(subLabel, sesLabel, runEntityLabels, taskRunLabels, suffix, bids)
%BUILD_BIDS_FUNC_PATTERNS Return ordered glob patterns for functional files.
%   The order is intentionally important:
%       1. task-runN labels, because this is the common layout for the current
%          project and excludes task-rest.
%       2. standard BIDS run entities, *_run-01_*.
%       3. optional broader task-only fallback only when bids.task is set.

    subjectPart = subLabel;
    if ~isempty(sesLabel)
        subjectPart = [subjectPart, '_', sesLabel];
    end

    optionalPart = build_optional_entity_pattern(bids);
    patterns = {};

    % Project layout: the repeated task acquisitions are encoded as task-run1,
    % task-run2, etc. This intentionally avoids matching task-rest.
    if ~has_nonempty_field(bids, 'task')
        for i = 1:numel(taskRunLabels)
            patterns{end+1} = [subjectPart, '_task-', taskRunLabels{i}, optionalPart, '_', suffix]; %#ok<AGROW>
        end
    end

    % Standard BIDS layout: task label plus a run entity. If task is not set,
    % allow any task except that run entity must still match the requested run.
    if has_nonempty_field(bids, 'task')
        taskPart = ['_task-', char(bids.task)];
    else
        taskPart = '_task-*';
    end
    for i = 1:numel(runEntityLabels)
        patterns{end+1} = [subjectPart, taskPart, '_', runEntityLabels{i}, optionalPart, '_', suffix]; %#ok<AGROW>
        patterns{end+1} = [subjectPart, '_*_', runEntityLabels{i}, optionalPart, '_', suffix]; %#ok<AGROW>
    end

    % Only use a task-only fallback when the user explicitly sets bids.task.
    % Without that guard, task-rest and task-runN files become ambiguous.
    if has_nonempty_field(bids, 'task')
        patterns{end+1} = [subjectPart, taskPart, optionalPart, '_', suffix]; %#ok<AGROW>
    end
end

function pattern = build_optional_entity_pattern(bids)
%BUILD_OPTIONAL_ENTITY_PATTERN Add optional BIDS entities for derivatives.
    pattern = '';
    if has_nonempty_field(bids, 'space')
        pattern = [pattern, '_space-', char(bids.space)];
    end
    if has_nonempty_field(bids, 'desc')
        pattern = [pattern, '_desc-', char(bids.desc)];
    end
end

function funcDirs = resolve_bids_func_dirs(root, subLabel, bids)
%RESOLVE_BIDS_FUNC_DIRS Return candidate BIDS func directories.
    subjectDir = fullfile(root, subLabel);
    directFuncDir = fullfile(subjectDir, 'func');
    funcDirs = struct('path', {}, 'session_label', {});

    if has_nonempty_field(bids, 'session')
        sesLabel = add_bids_entity_prefix(bids.session, 'ses');
        funcDirs(1).path = fullfile(subjectDir, sesLabel, 'func');
        funcDirs(1).session_label = sesLabel;
        return
    end

    if isfolder(directFuncDir)
        funcDirs(end+1).path = directFuncDir;
        funcDirs(end).session_label = '';
    end

    sessionDirs = dir(fullfile(subjectDir, 'ses-*'));
    sessionDirs = sessionDirs([sessionDirs.isdir]);
    sessionNames = sort({sessionDirs.name});
    for i = 1:numel(sessionNames)
        candidate = fullfile(subjectDir, sessionNames{i}, 'func');
        if isfolder(candidate)
            funcDirs(end+1).path = candidate; %#ok<AGROW>
            funcDirs(end).session_label = sessionNames{i};
        end
    end

    if isempty(funcDirs)
        funcDirs(1).path = directFuncDir;
        funcDirs(1).session_label = '';
    end
end

function runValue = resolve_requested_run_value(bids, runIndex)
%RESOLVE_REQUESTED_RUN_VALUE Return the user-requested run value.
    if has_nonempty_field(bids, 'runs')
        runValue = select_indexed_label(bids.runs, runIndex);
    else
        runValue = num2str(runIndex);
    end
end

function labels = make_bids_run_entity_labels(runValue)
%MAKE_BIDS_RUN_ENTITY_LABELS Return possible standard BIDS run entities.
    numericRun = str2double(run_value_to_char(runValue));
    labels = {};
    if ~isnan(numericRun)
        labels{end+1} = sprintf('run-%02d', numericRun); %#ok<AGROW>
        labels{end+1} = sprintf('run-%d', numericRun); %#ok<AGROW>
    else
        labels{end+1} = add_bids_entity_prefix(runValue, 'run'); %#ok<AGROW>
    end
    labels = unique(labels, 'stable');
end

function labels = make_task_run_labels(runValue)
%MAKE_TASK_RUN_LABELS Return possible task labels for run-coded task names.
    numericRun = str2double(run_value_to_char(runValue));
    labels = {};
    if ~isnan(numericRun)
        labels{end+1} = sprintf('run%d', numericRun); %#ok<AGROW>
        labels{end+1} = sprintf('run%02d', numericRun); %#ok<AGROW>
    else
        cleaned = run_value_to_char(runValue);
        cleaned = regexprep(cleaned, '^run[-_]?', '');
        labels{end+1} = ['run', cleaned]; %#ok<AGROW>
    end
    labels = unique(labels, 'stable');
end

function value = run_value_to_char(value)
%RUN_VALUE_TO_CHAR Convert numeric or string-like run values to char safely.
    if isnumeric(value)
        value = num2str(value);
    elseif isstring(value) && isscalar(value)
        value = char(value);
    else
        value = char(value);
    end
end

function label = select_indexed_label(labels, index)
%SELECT_INDEXED_LABEL Select a label from a numeric/cell/string label list.
    if isnumeric(labels)
        label = labels(index);
    elseif iscell(labels)
        label = labels{index};
    elseif isstring(labels)
        label = char(labels(index));
    else
        label = labels;
    end
    if isnumeric(label)
        label = num2str(label);
    else
        label = char(label);
        label = regexprep(label, '^run-', '');
    end
end

function value = get_optional_bids_value(bids, fieldName, defaultValue)
%GET_OPTIONAL_BIDS_VALUE Return a field value or a default.
    if has_nonempty_field(bids, fieldName)
        value = char(bids.(fieldName));
    else
        value = defaultValue;
    end
end

function tf = has_nonempty_field(s, fieldName)
%HAS_NONEMPTY_FIELD True when a struct field exists and is not empty.
    tf = isfield(s, fieldName) && ~isempty(s.(fieldName));
end

function value = add_bids_entity_prefix(value, entityName)
%ADD_BIDS_ENTITY_PREFIX Add a standard BIDS entity prefix if missing.
    if isnumeric(value)
        value = num2str(value);
    else
        value = char(value);
    end
    prefix = [entityName, '-'];
    if ~startsWith(value, prefix)
        value = [prefix, value];
    end
end
