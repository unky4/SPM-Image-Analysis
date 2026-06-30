function outputFiles = run_log_pipeline(settingsFilePath)
%RUN_LOG_PIPELINE Convert and optionally merge Presentation logs.
%
%   outputFiles = run_log_pipeline(settingsFilePath)
%
%   The settings file must contain a log_pipeline section with output_dir and
%   file_name. Logs can be read from BIDS subject folders or from a legacy flat
%   log_dir. If merge_inputs and merge_output_path are provided, the listed CSV
%   files are merged after conversion.

    settingsFilePath = char_if_string_scalar(settingsFilePath);
    spmia_setup_paths(mfilename('fullpath'));
    Settings = getsettings(settingsFilePath);
    assert(isfield(Settings, 'log_pipeline'), 'Missing log_pipeline section in %s', settingsFilePath);

    cfg = Settings.log_pipeline;
    if ~isfield(cfg, 'file_name') || isempty(cfg.file_name)
        cfg.file_name = 'data';
    end

    if isfield(cfg, 'logs') && isfield(cfg.logs, 'source') && strcmpi(cfg.logs.source, 'bids')
        logDir = '';
    else
        assert(isfield(cfg, 'log_dir') && ~isempty(cfg.log_dir), ...
               'log_pipeline.log_dir is required when log_pipeline.logs.source is not bids.');
        logDir = cfg.log_dir;
    end

    logs2stan(logDir, ...
              'settingsFilePath', settingsFilePath, ...
              'outputDir', cfg.output_dir, ...
              'fileName', cfg.file_name);

    outputFiles = struct();
    outputFiles.converted_csv = fullfile(cfg.output_dir, [cfg.file_name, '.csv']);

    if isfield(cfg, 'merge_inputs') && ~isempty(cfg.merge_inputs) && isfield(cfg, 'merge_output_path') && ~isempty(cfg.merge_output_path)
        merge_behavior_tables(cfg.merge_inputs, cfg.merge_output_path);
        outputFiles.merged_csv = cfg.merge_output_path;
    end
end

function value = char_if_string_scalar(value)
%CHAR_IF_STRING_SCALAR Convert scalar string paths to char vectors.
    if isstring(value) && isscalar(value)
        value = char(value);
    end
end
