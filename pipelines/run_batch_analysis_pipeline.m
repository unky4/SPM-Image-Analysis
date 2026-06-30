function run_batch_analysis_pipeline(batchYamlFilePath)
%RUN_BATCH_ANALYSIS_PIPELINE Run multiple analyses listed in one YAML file.
%
%   run_batch_analysis_pipeline(batchYamlFilePath)
%
%   The batch YAML should contain:
%       batch_pipeline.main_dir
%       batch_pipeline.settings_dir
%       batch_pipeline.groups2stest_path
%       batch_pipeline.regression_params_path
%       batch_pipeline.analyses: [analysis_a, analysis_b]
%
%   Each analysis is expected to have a settings_<analysis>.yaml file.

    %settingsFilePath = char_if_string_scalar(settingsFilePath);
    spmia_setup_paths(mfilename('fullpath'));
    Settings = getsettings(batchYamlFilePath);
    cfg = Settings.batch_pipeline;

    for i = 1:numel(cfg.analyses)
        analysisKey = cfg.analyses{i};
        settingsPath = fullfile(cfg.settings_dir, ['settings_', analysisKey, '.yaml']);
        analysisName = local_capitalize_first_char(analysisKey);

        firstlevelanalysis('settingsFilePath', settingsPath, ...
                           'jobFunction', 'firstlevelanalysis_job_default');
        secondlevelanalysis(analysisName, ...
            'settingsFilePath', settingsPath, ...
            'groups2stestPath', cfg.groups2stest_path, ...
            'regressionParamsPath', cfg.regression_params_path);
    end
end

function out = local_capitalize_first_char(in)
    if isempty(in)
        out = in;
    else
        out = [upper(in(1)), in(2:end)];
    end
end

function value = char_if_string_scalar(value)
%CHAR_IF_STRING_SCALAR Convert scalar string paths to char vectors.
    if isstring(value) && isscalar(value)
        value = char(value);
    end
end
