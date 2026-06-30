function path = getpaths(filePath)
% Return the full file path and parts
    path.fullPath = fullfile(filePath);
    [path.path, path.name, path.ext] = fileparts(path.fullPath);
end

