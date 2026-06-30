function run_preprocessing_pipeline(settingsFilePath, varargin)
%RUN_PREPROCESSING_PIPELINE Run the preprocessing workflow from YAML settings.
%
%   run_preprocessing_pipeline(settingsFilePath)
%   run_preprocessing_pipeline(settingsFilePath, 'nofNodesToUse', 4, 'nodeID', 2)
%
%   This pipeline is intentionally thin: it sets up paths, validates that the
%   settings file can be read, then delegates the SPM batch construction and
%   execution to preprocessing.m.

    settingsFilePath = char_if_string_scalar(settingsFilePath);
    spmia_setup_paths(mfilename('fullpath'));
    getsettings(settingsFilePath); % validate early, before SPM starts
    preprocessing('settingsFilePath', settingsFilePath, varargin{:});
end

function value = char_if_string_scalar(value)
%CHAR_IF_STRING_SCALAR Convert scalar string paths to char vectors.
    if isstring(value) && isscalar(value)
        value = char(value);
    end
end
