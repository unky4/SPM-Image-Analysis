function projectRoot = spmia_setup_paths(callerFile)
%SPMIA_SETUP_PATHS Add project subfolders needed by the SPM image toolbox.
%
%   projectRoot = spmia_setup_paths(callerFile)
%
%   Inputs
%   ------
%   callerFile : char
%       Full path of the calling function, normally provided as
%       mfilename('fullpath').
%
%   Outputs
%   -------
%   projectRoot : char
%       Absolute path to the toolbox root.

    if nargin < 1 || isempty(callerFile)
        projectRoot = pwd;
    else
        projectRoot = fileparts(callerFile);
        if strcmp(get_last_path_part(projectRoot), 'pipelines')
            projectRoot = fileparts(projectRoot);
        end
    end

    addpath(fullfile(projectRoot, 'functions'));
    addpath(fullfile(projectRoot, 'log_file_readers'));
    addpath(fullfile(projectRoot, 'spm_jobs'));
    addpath(fullfile(projectRoot, 'pipelines'));
end

function part = get_last_path_part(pathIn)
    [~, part] = fileparts(pathIn);
end
