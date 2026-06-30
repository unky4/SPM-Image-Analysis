function InputArgs = parseinput(functionName, varargin)
%PARSEINPUT Parse name-value inputs for toolbox entry points.
%
%   InputArgs = parseinput(functionName, varargin)
%
%   The parser uses 'settingsFilePath' as the preferred option. The
%   'settingsJsonFilePath' option is still accepted to avoid breaking older
%   scripts.

    switch (functionName)
        case 'log2stan'
            InputArgs = parse_log2stan(varargin{:});
        case 'preprocessing'
            InputArgs = parse_preprocessing(varargin{:});
        case 'firstlevelanalysis'
            InputArgs = parse_firstlevelanalysis(varargin{:});
        case 'secondlevelanalysis'
            InputArgs = parse_secondlevelanalysis(varargin{:});
        otherwise
            error(['Cannot parse the input because it has not been defined ' ...
                   'for the function called: ', functionName])
    end
end

function InputArgs = parse_log2stan(varargin)
%PARSE_LOG2STAN Parse inputs for log conversion.
    p = inputParser;
    addSettingsParameters(p);
    addParameter(p, 'outputDir', '', @is_text_scalar);
    addParameter(p, 'fileName', 'data', @is_text_scalar);
    parse(p, varargin{:});
    InputArgs = normaliseSettingsPath(p.Results);
end

function InputArgs = parse_preprocessing(varargin)
%PARSE_PREPROCESSING Parse inputs for preprocessing.
    p = inputParser;
    addSettingsParameters(p);
    addParameter(p, 'jobFunction', 'preprocessing_job', @is_text_scalar);
    addParameter(p, 'nofNodesToUse', 1, @(x) (x > 0) && isnumeric(x) && isscalar(x));
    addParameter(p, 'nodeID', 1, @(x) (x > 0) && isnumeric(x) && isscalar(x));
    parse(p, varargin{:});
    InputArgs = normaliseSettingsPath(p.Results);
    InputArgs.jobFunction = str2func(char(InputArgs.jobFunction));
end

function InputArgs = parse_firstlevelanalysis(varargin)
%PARSE_FIRSTLEVELANALYSIS Parse inputs for first-level analysis.
    p = inputParser;
    addSettingsParameters(p);
    addParameter(p, 'logFileReaderFunction', 'logreader', @is_text_scalar);
    addParameter(p, 'jobFunction', 'firstlevelanalysis_job', @is_text_scalar);
    addParameter(p, 'nofNodesToUse', 1, @(x) (x > 0) && isnumeric(x) && isscalar(x));
    addParameter(p, 'nodeID', 1, @(x) (x > 0) && isnumeric(x) && isscalar(x));
    parse(p, varargin{:});
    InputArgs = normaliseSettingsPath(p.Results);
    InputArgs.logFileReaderFunction = str2func(char(InputArgs.logFileReaderFunction));
    InputArgs.jobFunction = str2func(char(InputArgs.jobFunction));
end

function InputArgs = parse_secondlevelanalysis(varargin)
%PARSE_SECONDLEVELANALYSIS Parse inputs for second-level analysis.
    p = inputParser;
    addSettingsParameters(p);
    addParameter(p, 'jobFunction1STTest', 'secondlevelanalysis1sttest_job', @is_text_scalar);
    addParameter(p, 'jobFunctionRegression', 'secondlevelanalysisregression_job', @is_text_scalar);
    addParameter(p, 'regressionParamsPath', '', @is_text_scalar);
    addParameter(p, 'jobFunction2STTest', 'secondlevelanalysis2sttest_job', @is_text_scalar);
    addParameter(p, 'groups2stestPath', cell(0, 0), @(x) is_text_scalar(x) || iscell(x));
    addParameter(p, 'jobFunctionAnova', 'secondlevelanalysisanova_job', @is_text_scalar);
    addParameter(p, 'anovaGroupsPath', '', @is_text_scalar);
    parse(p, varargin{:});
    InputArgs = normaliseSettingsPath(p.Results);
    InputArgs.jobFunction1STTest = str2func(char(InputArgs.jobFunction1STTest));
    InputArgs.jobFunctionRegression = str2func(char(InputArgs.jobFunctionRegression));
    InputArgs.jobFunction2STTest = str2func(char(InputArgs.jobFunction2STTest));
    if is_text_scalar(InputArgs.groups2stestPath)
        InputArgs.groups2stestPath = {char(InputArgs.groups2stestPath)};
    elseif iscell(InputArgs.groups2stestPath)
        InputArgs.groups2stestPath = cellfun(@char_if_string, InputArgs.groups2stestPath, 'UniformOutput', false);
    end
    InputArgs.jobFunctionAnova = str2func(char(InputArgs.jobFunctionAnova));
end

function addSettingsParameters(p)
%ADDSETTINGSPARAMETERS Add settings-file options.
    addParameter(p, 'settingsFilePath', 'settings.yaml', @is_text_scalar);
    addParameter(p, 'settingsYamlFilePath', '', @is_text_scalar);
    addParameter(p, 'settingsJsonFilePath', '', @is_text_scalar);
end

function InputArgs = normaliseSettingsPath(InputArgs)
%NORMALISESETTINGSPATH Resolve settings-file option names.
    if isfield(InputArgs, 'settingsYamlFilePath') && ~isempty(InputArgs.settingsYamlFilePath)
        InputArgs.settingsFilePath = InputArgs.settingsYamlFilePath;
    elseif isfield(InputArgs, 'settingsJsonFilePath') && ~isempty(InputArgs.settingsJsonFilePath)
        InputArgs.settingsFilePath = InputArgs.settingsJsonFilePath;
    end

    % Keep the rest of the toolbox compatible with older MATLAB code that
    % expects character vectors rather than string scalars.
    fields = fieldnames(InputArgs);
    for iField = 1:numel(fields)
        name = fields{iField};
        if is_text_scalar(InputArgs.(name))
            InputArgs.(name) = char(InputArgs.(name));
        end
    end
end

function tf = is_text_scalar(x)
%IS_TEXT_SCALAR True for character vectors and scalar MATLAB strings.
    tf = ischar(x) || (isstring(x) && isscalar(x));
end

function y = char_if_string(x)
%CHAR_IF_STRING Convert scalar string values to char for older MATLAB code.
    if isstring(x) && isscalar(x)
        y = char(x);
    else
        y = x;
    end
end
