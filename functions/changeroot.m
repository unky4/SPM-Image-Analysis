function Info = changeroot(Info, Settings)
% Change the root in the paths. This is so that if you move to another PC
% you can still use the preprocessed etc files.
%
%   Input:
%       - Info: The struct containing the paths
%       - Settings: The settings structure loaded from the JSON file
%                   See getsettings.m function
%
%   Output:
%       - The updated Info
    
    % define the fields that a path will have
    pathFields = {'fullPath', 'path', 'name', 'ext'};
    
    % Get all path field
    fields = fieldnames(Info.paths)';
    
    % Get previous root folders
    saveRootOLD = replace(Info.paths.preprocessingSave.path, 'preprocessing', '');
    
    for i = 1:numel(fields)
        field = fields{i};
        
        switch field
            case 'SPM'
                Info.paths.(field) = getpaths(Settings.spmPath);
            case 'originalData'
                Info.paths.(field) = getpaths(Settings.functionalPath);
            otherwise
                Info.paths.(field) = changesubfileds(Info.paths.(field), pathFields, saveRootOLD, Settings.saveRoot);
        end
    end
end

function path = changesubfileds(path, pathFields, oldPath, newPath)
% Change all subfields
    for i = 1:numel(pathFields)
        for j = 1:numel(path)
            if isempty(path(j)) || isempty(path(j).(pathFields{i}))
                continue
            end

            % Replace root folder
            path(j).(pathFields{i}) = replace(path(j).(pathFields{i}), oldPath, newPath);
        
            % Repace slash with backslash and vica versa
            if contains(newPath, '\')
                path(j).(pathFields{i}) = replace(path(j).(pathFields{i}), '/', '\');
            else
                path(j).(pathFields{i}) = replace(path(j).(pathFields{i}), '\', '/');
            end
        end
    end
end

