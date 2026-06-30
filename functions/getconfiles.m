function conFiles = getconfiles(conFilesDir, conNumber)
% Collect the first level analysis con files
%
%   Inputs:
%       - conFilesDir: Folder where the confiles are
%                      should be: Info.paths.secondlaSave.fullPath
%
%   Outputs:
%       - conFiles: Cell of path to the con files
%
    
    arguments
        conFilesDir (1,:) char;
        conNumber (1,:) char = '0001';
    end

    conFiles = dir(conFilesDir);
    conFiles = {conFiles.name}';
    conFiles = conFiles(cellfun(@(x) contains(x, '_mask'), conFiles));
    [~, ~, ext] = fileparts(conFiles{1});
    if ~strcmp(ext, '.nii')
        ext = '.img';
    end
    [~, conFiles, ~] = fileparts(conFiles);
    conFiles = unique(conFiles);
    conFiles = strrep(conFiles, '_mask', ['_con_', conNumber, ext, ',1']);
    if ~exist(fullfile(conFilesDir, replace(conFiles{1}, ',1', '')), 'file')
        conFiles = strrep(conFiles, '_con_', '_ess_');
    end
    for i = 1:length(conFiles)
        conFiles{i} = fullfile(conFilesDir, conFiles{i});
    end
end

