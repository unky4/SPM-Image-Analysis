function run_prediction_error_pipeline(settingsFilePath, varargin)
    settingsFilePath = char_if_string_scalar(settingsFilePath);
%RUN_PREDICTION_ERROR_PIPELINE Run a PE-based first/second-level analysis.
%
%   run_prediction_error_pipeline(settingsFilePath)
%
%   This specialised pipeline is a readable alias for PE analyses. The YAML
%   file should point first_level_analysis.data_path to the behavioural CSV
%   that contains the prediction-error column and should set the pmod name to
%   that column.

    run_analysis_pipeline(settingsFilePath, varargin{:});
end

function value = char_if_string_scalar(value)
%CHAR_IF_STRING_SCALAR Convert scalar string paths to char vectors.
    if isstring(value) && isscalar(value)
        value = char(value);
    end
end
