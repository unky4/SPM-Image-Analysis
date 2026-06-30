function [partitionedLog, Inds] = getpartitionedcelllog(logFilePath, newSessionPhrase, timeScaler, isFirstExperimentStart, varargin)
% Partitions the log file into tasks
%
%   Inputs:
%       - logFilePath: Path of the logfile that you are trying to partition
%   Outputs:
%       - partitionedLog: Partitioned log data
%
    nofDiscards = -1;
    if ~isempty(varargin)
        nofDiscards = varargin{1};
    end

    % Get the log file in a cell array
    rawData = log2numtxt(logFilePath);
    
    % Init output
    partitionedLog = cell(1,1);
    
    % Get index of code and event type columns
    headerRow = rawData(4, :);
    eventTypeInd = find(cellfun(@(x)isequal(x, 'Event Type'), headerRow));
    codeInd = find(cellfun(@(x)isequal(x, 'Code'), headerRow));
    timeInd = find(cellfun(@(x)isequal(x, 'Time'), headerRow));
    Inds = struct('eventType', eventTypeInd, ...
                  'code', codeInd, ...
                  'time', timeInd);
    
    % Find first row where
    %   -The data starts
    %   -The experiment starts
    if nofDiscards == -1
        if isFirstExperimentStart
            firstRowExp = findfirstincell(rawData(:, codeInd), newSessionPhrase);
        else
            firstRowExp = findfirstnot(rawData(:, eventTypeInd), 'Pulse');
        end
    else
        mask = ~cellfun('isempty', regexp(cellstr(rawData(:, eventTypeInd)), "\<" + 'Pulse' + "\>", 'once'));
        idx = find(mask);
        
        if numel(idx) >= nofDiscards + 1
            firstRowExp = idx(nofDiscards + 1);
        else
            error('Not enough occurrences')
        end
    end

    % Normalise and scale time
    %   Note: Start time is the Pulse right before the first image
    %         presented. If no Pulse before the first image then the first
    %         image is the start time.
    try
        startTime = rawData{firstRowExp, timeInd};
    catch
        A = 0;
    end
    for i = firstRowExp:-1:1
        if strcmp(rawData{i, 2}, 'Pulse')
            startTime = rawData{i, timeInd};
            break;
        end
    end
    rawData(firstRowExp:end, timeInd) = cellfun(@(x) (x - startTime) ./ timeScaler, rawData(firstRowExp:end, timeInd), 'UniformOutput', false);
    
    % Get first trial start index
    firstRowExp = findfirstincell(rawData(:, codeInd), newSessionPhrase);

    % Split the raw data into bloks
    chunkCount = 0;
    chunkInd = 1;
    for i = firstRowExp:size(rawData, 1)
        if ~isnumeric(rawData{i, codeInd}) && contains(rawData{i, codeInd}, newSessionPhrase)
            chunkCount = chunkCount + 1;
            chunkInd = 1;
        end
        
        % Save the row into the right chunk
        for j = 1:length(rawData(i,:))
            partitionedLog{chunkCount}{chunkInd,j} = rawData{i,j};
        end

        chunkInd = chunkInd + 1;
    end
end

