function startup_spm_image_analysis()
%STARTUP_SPM_IMAGE_ANALYSIS Add the toolbox folders to the MATLAB path.
%
%   startup_spm_image_analysis()
%
%   Run this function once at the start of a MATLAB session before calling
%   the preprocessing, first-level, second-level, or log-processing
%   pipelines. The function resolves paths relative to this file, so it can
%   be called from any working directory.

    projectRoot = fileparts(mfilename('fullpath'));
    addpath(projectRoot);
    addpath(fullfile(projectRoot, 'functions'));
    addpath(fullfile(projectRoot, 'log_file_readers'));
    addpath(fullfile(projectRoot, 'spm_jobs'));
    addpath(fullfile(projectRoot, 'pipelines'));
end
