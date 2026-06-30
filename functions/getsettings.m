function Settings = getsettings(settingsFilePath)
%GETSETTINGS Load toolbox settings from YAML or JSON.
%
%   Settings = getsettings(settingsFilePath)
%
%   Inputs
%   ------
%   settingsFilePath : char
%       Path to a .yaml, .yml, or .json settings file. YAML is recommended
%       because it supports comments. JSON remains supported when needed.
%
%   Outputs
%   -------
%   Settings : struct
%       Settings structure used by the preprocessing and analysis functions.
%
%   Notes
%   -----
%   YAML loading is attempted in this order:
%       1. ReadYaml, if available on the MATLAB path.
%       2. Python yaml.safe_load, if MATLAB can access PyYAML.
%       3. A small built-in YAML reader for the simple key/value structure
%          used by the example files in this toolbox.

    if nargin < 1 || isempty(settingsFilePath)
        settingsFilePath = 'settings.yaml';
    elseif isstring(settingsFilePath) && isscalar(settingsFilePath)
        settingsFilePath = char(settingsFilePath);
    end

    [~, ~, ext] = fileparts(settingsFilePath);
    switch lower(ext)
        case '.json'
            Settings = loadfromjson(settingsFilePath);
        case {'.yaml', '.yml'}
            Settings = loadfromyaml(settingsFilePath);
        otherwise
            error('Unsupported settings file extension: %s', ext);
    end

    Settings = normalise_bids_settings(Settings);
    Settings = normalise_log_settings(Settings);

    if ~isfield(Settings, 'nofSessions') && isfield(Settings, 'startSession') && isfield(Settings, 'endSession')
        Settings.nofSessions = Settings.endSession - Settings.startSession + 1;
    end
end

function Settings = normalise_log_settings(Settings)
%NORMALISE_LOG_SETTINGS Fill internal log-conversion compatibility fields.
    if isfield(Settings, 'log_file_run_suffix') && ~isfield(Settings, 'sessionSuffix')
        Settings.sessionSuffix = Settings.log_file_run_suffix;
    elseif ~isfield(Settings, 'sessionSuffix')
        Settings.sessionSuffix = '';
    end
end

function Settings = normalise_bids_settings(Settings)
%NORMALISE_BIDS_SETTINGS Fill internal legacy fields from BIDS settings.
%   Public YAML files use BIDS runs. The older analysis functions still use
%   startSession/endSession internally, so this function maps run indices to
%   those internal counters without exposing BIDS prefixes or legacy naming to
%   users.

    if ~isfield(Settings, 'bids') || ~isstruct(Settings.bids)
        return
    end
    if ~isfield(Settings.bids, 'enabled') || ~Settings.bids.enabled
        return
    end

    if ~isfield(Settings.bids, 'suffix') || isempty(Settings.bids.suffix)
        Settings.bids.suffix = 'bold';
    end

    % Backwards compatibility: accept older field name subjects, but prefer
    % subject_labels in public settings files.
    if ~isfield(Settings.bids, 'subject_labels') && isfield(Settings.bids, 'subjects')
        Settings.bids.subject_labels = Settings.bids.subjects;
    end

    % Backwards compatibility: accept startRun/endRun, or older
    % startSession/endSession, but prefer bids.runs in public settings files.
    if ~isfield(Settings.bids, 'runs') || isempty(Settings.bids.runs)
        if isfield(Settings.bids, 'startRun') && isfield(Settings.bids, 'endRun')
            Settings.bids.runs = Settings.bids.startRun:Settings.bids.endRun;
        elseif isfield(Settings, 'startSession') && isfield(Settings, 'endSession')
            Settings.bids.runs = Settings.startSession:Settings.endSession;
        else
            Settings.bids.runs = 1;
        end
    end

    % Internal compatibility with the original implementation. These fields
    % are not required in BIDS YAML configs.
    Settings.startSession = 1;
    Settings.endSession = numel(Settings.bids.runs);
    Settings.nofSessions = numel(Settings.bids.runs);
    if ~isfield(Settings, 'functionalPath') || isempty(Settings.functionalPath)
        Settings.functionalPath = Settings.bids.root;
    end
    if ~isfield(Settings, 'functionalSuffix')
        Settings.functionalSuffix = '';
    end
    if ~isfield(Settings, 'sessionSuffix')
        Settings.sessionSuffix = '_run';
    end
end

function json = loadfromjson(jsonFilePath)
%LOADFROMJSON Load a JSON settings file into a MATLAB structure.
    fid = fopen(jsonFilePath, 'r');
    assert(fid > 0, 'Could not open settings file: %s', jsonFilePath);
    cleaner = onCleanup(@() fclose(fid));
    json = jsondecode(char(fread(fid, inf)'));
end

function data = loadfromyaml(yamlFilePath)
%LOADFROMYAML Load YAML using the best available backend.
    if exist('ReadYaml', 'file') == 2
        data = ReadYaml(yamlFilePath);
        data = normalise_struct_fields(data);
        return
    end

    try
        yamlText = fileread(yamlFilePath);
        pyObj = py.yaml.safe_load(yamlText);
        data = py_to_matlab(pyObj);
        data = normalise_struct_fields(data);
        return
    catch
        % Fall through to the minimal parser below. This keeps the toolbox
        % usable on systems without PyYAML or third-party MATLAB YAML code.
    end

    data = parse_simple_yaml(fileread(yamlFilePath));
    data = normalise_struct_fields(data);
end

function value = py_to_matlab(pyObj)
%PY_TO_MATLAB Recursively convert common Python containers to MATLAB values.
    cls = class(pyObj);
    if strcmp(cls, 'py.dict')
        value = struct();
        keys = cell(pyObj.keys());
        for i = 1:numel(keys)
            key = char(keys{i});
            value.(matlab.lang.makeValidName(key)) = py_to_matlab(pyObj{keys{i}});
        end
    elseif strcmp(cls, 'py.list') || strcmp(cls, 'py.tuple')
        cells = cell(pyObj);
        value = cell(size(cells));
        for i = 1:numel(cells)
            value{i} = py_to_matlab(cells{i});
        end
        if all(cellfun(@isnumeric, value))
            value = cell2mat(value);
        end
    elseif strcmp(cls, 'py.str')
        value = char(pyObj);
    elseif strcmp(cls, 'py.bool')
        value = logical(pyObj);
    elseif contains(cls, 'float') || contains(cls, 'int')
        value = double(pyObj);
    elseif strcmp(cls, 'py.NoneType')
        value = '';
    else
        value = char(pyObj);
    end
end

function data = parse_simple_yaml(yamlText)
%PARSE_SIMPLE_YAML Minimal parser for commented toolbox settings files.
%   This reader supports nested mappings, quoted/unquoted scalars, inline
%   arrays, and simple block lists. It is not intended to be a general YAML
%   implementation.
    rawLines = regexp(yamlText, '\r?\n', 'split')';
    data = struct();
    pathStack = {''};
    indentStack = -1;
    lastKeyByLevel = containers.Map('KeyType', 'double', 'ValueType', 'char');

    for lineIdx = 1:numel(rawLines)
        rawLine = strip_comment(rawLines{lineIdx});
        if isempty(strtrim(rawLine))
            continue
        end
        indent = length(rawLine) - length(regexprep(rawLine, '^\s*', ''));
        line = strtrim(rawLine);

        while indent <= indentStack(end) && numel(indentStack) > 1
            indentStack(end) = [];
            pathStack(end) = [];
        end

        if startsWith(line, '- ')
            itemText = strtrim(extractAfter(line, 2));
            parentPath = pathStack{end};
            existing = get_nested_value(data, parentPath);
            if isempty(existing) || isstruct(existing)
                existing = {};
            end
            existing{end+1} = parse_scalar(itemText);
            data = set_nested_value(data, parentPath, existing);
            continue
        end

        tokens = regexp(line, '^([^:]+):\s*(.*)$', 'tokens', 'once');
        if isempty(tokens)
            continue
        end
        key = clean_key(tokens{1});
        valueText = strtrim(tokens{2});
        currentParent = pathStack{end};
        currentPath = join_path(currentParent, key);
        lastKeyByLevel(indent) = currentPath;

        if isempty(valueText)
            data = set_nested_value(data, currentPath, struct());
            indentStack(end+1) = indent;
            pathStack{end+1} = currentPath;
        else
            data = set_nested_value(data, currentPath, parse_scalar(valueText));
        end
    end
end

function key = clean_key(key)
%CLEAN_KEY Convert a YAML key to a valid MATLAB struct field name.
    key = strtrim(key);
    key = regexprep(key, '^[''\"]|[''\"]$', '');
    key = matlab.lang.makeValidName(key);
end

function p = join_path(parent, key)
%JOIN_PATH Join dotted struct paths.
    if isempty(parent)
        p = key;
    else
        p = [parent, '.', key];
    end
end

function line = strip_comment(line)
%STRIP_COMMENT Remove comments outside quoted strings.
    inSingle = false;
    inDouble = false;
    keep = true(size(line));
    for i = 1:length(line)
        ch = line(i);
        if ch == '''' && ~inDouble
            inSingle = ~inSingle;
        elseif ch == '"' && ~inSingle
            inDouble = ~inDouble;
        elseif ch == '#' && ~inSingle && ~inDouble
            keep(i:end) = false;
            break
        end
    end
    line = line(keep);
end

function value = parse_scalar(text)
%PARSE_SCALAR Parse a YAML scalar or inline array.
    text = strtrim(text);
    if isempty(text) || strcmp(text, 'null') || strcmp(text, '~')
        value = '';
    elseif any(strcmpi(text, {'true', 'false'}))
        value = strcmpi(text, 'true');
    elseif startsWith(text, '[') && endsWith(text, ']')
        inside = strtrim(text(2:end-1));
        if isempty(inside)
            value = [];
            return
        end
        parts = split_inline_array(inside);
        values = cell(size(parts));
        for i = 1:numel(parts)
            values{i} = parse_scalar(parts{i});
        end
        if all(cellfun(@(x) isnumeric(x) && isscalar(x), values))
            value = cell2mat(values);
        else
            value = values;
        end
    elseif (startsWith(text, '"') && endsWith(text, '"')) || (startsWith(text, '''') && endsWith(text, ''''))
        value = text(2:end-1);
    else
        numericValue = str2double(text);
        if ~isnan(numericValue)
            value = numericValue;
        else
            value = text;
        end
    end
end

function parts = split_inline_array(text)
%SPLIT_INLINE_ARRAY Split comma-separated arrays while respecting quotes.
    parts = {};
    current = '';
    inSingle = false;
    inDouble = false;
    for i = 1:length(text)
        ch = text(i);
        if ch == '''' && ~inDouble
            inSingle = ~inSingle;
        elseif ch == '"' && ~inSingle
            inDouble = ~inDouble;
        elseif ch == ',' && ~inSingle && ~inDouble
            parts{end+1} = strtrim(current); %#ok<AGROW>
            current = '';
            continue
        end
        current = [current, ch]; %#ok<AGROW>
    end
    parts{end+1} = strtrim(current);
end

function s = set_nested_value(s, dottedPath, value)
%SET_NESTED_VALUE Set a nested field using a dotted path.
    fields = strsplit(dottedPath, '.');
    if numel(fields) == 1
        s.(fields{1}) = value;
    else
        f = fields{1};
        rest = strjoin(fields(2:end), '.');
        if ~isfield(s, f) || ~isstruct(s.(f))
            s.(f) = struct();
        end
        s.(f) = set_nested_value(s.(f), rest, value);
    end
end

function value = get_nested_value(s, dottedPath)
%GET_NESTED_VALUE Read a nested field using a dotted path.
    if isempty(dottedPath)
        value = s;
        return
    end
    fields = strsplit(dottedPath, '.');
    value = s;
    for i = 1:numel(fields)
        if isstruct(value) && isfield(value, fields{i})
            value = value.(fields{i});
        else
            value = [];
            return
        end
    end
end

function s = normalise_struct_fields(s)
%NORMALISE_STRUCT_FIELDS Make nested struct field names MATLAB-compatible.
    if isstruct(s)
        fields = fieldnames(s);
        for i = 1:numel(fields)
            oldName = fields{i};
            newName = matlab.lang.makeValidName(oldName);
            s.(oldName) = normalise_struct_fields(s.(oldName));
            if ~strcmp(oldName, newName)
                s.(newName) = s.(oldName);
                s = rmfield(s, oldName);
            end
        end
    elseif iscell(s)
        for i = 1:numel(s)
            s{i} = normalise_struct_fields(s{i});
        end
    end
end
