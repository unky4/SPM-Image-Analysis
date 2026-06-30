function varargout = log2numtxt(filePath)
% Reads a .log file (which is a tab sperated text file) form filePath
%
% This tries to do the same thing as:
%   [num, txt] = xlsread(filePath);
% but with a .log file
%
% Or if the number of outputs is 1 then it gives back the original one in a
% cell format
%   rawData = xlsread(filePath);
%

    % Make sure that this is a .log file
    [~, ~, logfileExtension] = fileparts(filePath);
    switch logfileExtension
        case '.mat'
            % Nothing to change jsut return with the loaded mat file
            % Return
            rawData = load(filePath);
            
            if isstruct(rawData)
                fields = fieldnames(rawData);
                if numel(fields) == 1
                    varargout{1} = rawData.(fields{1});
                else
                    error('Multiple fileds has not heen handled')
                end
            elseif iscell(rawData)
                varargout{1} = rawData;
            else
                error('This type of mat file has not been handled.')
            end
            
        case '.log'
            % Set some options
            opts = detectImportOptions(filePath);
            opts.Delimiter{1} = '\t';
            opts.DataLines = [1,Inf];
            opts.EmptyLineRule = 'read';
            
            % Read the file
            rawData = readcell(filePath, opts);
            
            if nargout == 1
                % Get only the texts
                for i = 1:numel(rawData)
                    % If the cell is not a text and number then replace it
                    % with ''
                    if ~ischar(rawData{i}) && ~isnumeric(rawData{i})
                        rawData{i} = '';
                    end
                end
                
                % Return
                varargout{1} = rawData;
                
            elseif nargout == 2
                % Get only the numbers
                num = NaN(size(rawData));
                for i = 1:numel(rawData)
                    if isnumeric(rawData{i})
                        num(i) = rawData{i};
                    end
                end

                % Delete the rows and columns that are full NaNs
                % but only up till the first non-nan column/row
                firstNumRow = find(~all(isnan(num), 2), 1);
                num(1:firstNumRow-1, :) = []; % for rows
                firstNumCol = find(~all(isnan(num), 1), 1);
                num(:, 1:firstNumCol-1) = [];   % for columns

                % Get only the texts
                txt = cell(size(rawData));
                for i = 1:numel(txt)
                    % If the cell is a text then store it else we just fill in
                    % with ''
                    if ischar(rawData{i})
                        txt{i} = rawData{i};
                    else
                        txt{i} = '';
                    end
                end
                
                % Return
                varargout{1} = num;
                varargout{2} = txt;
                
            else
                error(['Number of outputs: ', num2str(nargout), ' is not supported.'])
            end
            
        otherwise
            error(['The extension of the logfile ', logfileExtension, ' is not supported, only .log files are'])
    end
end

