function run_analysis_pipeline(settingsFilePath, varargin)
%RUN_ANALYSIS_PIPELINE Run first- and second-level analyses from one config.
%
%   run_analysis_pipeline(settingsFilePath)
%
%   The settings YAML may contain an analysis_pipeline section with fields:
%       analysis_name, groups2stest_path, regression_params_path,
%       first_level_job, and run_first_level.
%
%   This replaces long ad-hoc scripts with one documented entry point.

    settingsFilePath = char_if_string_scalar(settingsFilePath);
    spmia_setup_paths(mfilename('fullpath'));
    Settings = getsettings(settingsFilePath);

    if isfield(Settings, 'analysis_pipeline')
        cfg = Settings.analysis_pipeline;
    else
        cfg = struct();
    end

    if ~isfield(cfg, 'analysis_name') || isempty(cfg.analysis_name)
        [~, name] = fileparts(settingsFilePath);
        cfg.analysis_name = regexprep(name, '^settings[_-]?', '');
    end
    if ~isfield(cfg, 'first_level_job') || isempty(cfg.first_level_job)
        cfg.first_level_job = 'firstlevelanalysis_job_default';
    end
    if ~isfield(cfg, 'run_first_level') || isempty(cfg.run_first_level)
        cfg.run_first_level = true;
    end
    if ~isfield(cfg, 'groups2stest_path')
        cfg.groups2stest_path = {};
    end
    if ischar(cfg.groups2stest_path)
        cfg.groups2stest_path = {cfg.groups2stest_path};
    end
    if ~isfield(cfg, 'regression_params_path')
        cfg.regression_params_path = '';
    end

    if cfg.run_first_level
        firstlevelanalysis('settingsFilePath', settingsFilePath, ...
                           'jobFunction', cfg.first_level_job, varargin{:});
    end

    secondlevelanalysis(cfg.analysis_name, ...
        'settingsFilePath', settingsFilePath, ...
        'groups2stestPath', cfg.groups2stest_path, ...
        'regressionParamsPath', cfg.regression_params_path);
end

function value = char_if_string_scalar(value)
%CHAR_IF_STRING_SCALAR Convert scalar string paths to char vectors.
    if isstring(value) && isscalar(value)
        value = char(value);
    end
end
