function mergestanlogs(stanLogs, outputPath)
% Takes stan log files and merge them together
%   Stan logs are created with log2stan function
%
%   Inputs:
%       - stanLogs: Stan log files in a cell array
%       - outputDir: Output path (including the filename)

    % Read logs
    logs = cell(numel(stanLogs), 1);
    for i = 1: numel(stanLogs)
        logs{i} = readtable(stanLogs{i}, 'Delimiter', ',');
    end
    
    % Merge
    logsMerged = [];
    for i = 1:numel(logs)
        logsMerged = [logsMerged; logs{i}];
    end

    % Save
    writetable(logsMerged, outputPath);
end