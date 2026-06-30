function varargout = readlog(varargin)

% leave them 4
% 
% 
% choice_reward_0', 'choice_reward_100', 'noChoice_reward_0', 'noChoice_reward_100
% 
%      	-1		  1		     -1			   +1
% 
% 0,-1,0,1,0,-1,0+1
% 
% 
% exclude if cannot do first lvl analysis
% 
% 
% 
% choice_reward_0 & noChoice_reward_0		choice_reward_100 & noChoice_reward_100
% 		-1						1
% 
% 0,-1,0,1











% Reads log file for the stradl dataset
%
%   Inputs:
%       - inputPath: Path of the logfile that you are trying to read the
%                    info out of
%       - outputPath: Where you want to save the output mat file
%                     Only folder without the file name pls
%
%   Outputs:
%
%
%   Usage:
%       - path = readlog(inputPath): Return with the path of the output
%                                    file.
%                                    - If you have the function called:
%                                      'getpaths', then it will give you a 
%                                      struct that has 4 fields:
%                                         - path.fullPath
%                                         - path.path
%                                         - path.name
%                                         - path.ext
%                                    - If you don't have it it will only
%                                      give you the fullfile path
%       - readlog(inputPath, outputPath): Only saves the mat file
%
%   Assumptions:
%       - Event Type: is in the 3rd column
%       - Code: is in the 4th column
%       - Time: is in the 5th column

    
    % -------------------------------------------------------------------------------------------------------------------------------
    %   Define used variables
    % ------------------------- You CAN modify this part
    % Save the output with this suffix
    suffix = '_loginfo';
    
    % Initialise the struct where we store all data and what we will save
    Info = struct();
    
    % Units for the MRI
    Info.units = 'secs';
    
    % Define the names for the two category where we categorise each
    % block/trial
    %   - Info.names: contians the names which will be displayed in SPM
    %   - splitByNames: are the names that is in the log files and which I
    %                   use to group the a block/trial
    %   Note: Although they can be different, make sure that their length
    %         is the same please
    Info.names = {'reward_win', 'reward_nothing', 'lose_lose', 'lose_nothing'};
    splitByNames = {'rew', 'rew', 'los', 'los'};
    %Info.names = {'reward_win', 'reward_nothing'};
    %splitByNames = {'rew', 'rew'};
    %Info.names = {'lose_lose', 'lose_nothing'};
    %splitByNames = {'los', 'los'};
    
    % Define the contrasts matrix
    %   Notes:
    %       - Number of columns has to be length(splitByNames)
    %       - most contains only 0, 1 and -1
    %   	- Each row defines a contrast
    %       - This does NOT include the hemodynamic response functions and
    %         so, for example in the first level analysis you may need
    %         twice as wide matrix
    %           Example:
    %               Original: [1, -1]
    %               Needed by SPM: [0, 1, 0, -1]
    %         You can just add zeros to every second column to solve this
    %         problem by something like this:
    %           weight = zeros(2 * length(Info.contrasts.vectors{i}), 1);
    %           weight(2:2:end) = loginfo.contrasts.vectors{i};
    %         Or
    %           weight(1:2:end-1) = loginfo.contrasts.vectors{i};
    %         depending on what you want to do
    %   Automatic Name Generation Examples:
    %       - 1, 0 --> Name_1
    %       - 0, 1 --> Name_2
    %       - 1, 1 --> Name_1 & Name_2
    %       - 1, -1 --> Name_1 & -Name_2
    %       - -1, 1 --> -Name_1 & Name_2
	contrastsMatrix = [1,0,0,0];
    %contrastsMatrix = [1,-1];
    %contrastsMatrix = [-1,1];

    
    % Initialise the struct where we store all the phrases needed
    Phrases = struct();
    
    % Define phrase that indicates that this is a new block
    % You can define more than one seperator, each time at least one is
    % present, it will start a new block
    %   Note: block means esentially a new section i.e. a choice image and
    %         all the response to it before a new choice image is shown.
    %         And not the block design
    Phrases.newSession = {'trial_'};
    
    % Define the words that a bad trial would have
    %   Note: If any of these is found then this is a bad trial
    %         and we ignore it completely
    Phrases.badTrial = {'no response'};
    
    % Define the response phrase
    Phrases.response = {1, 2};
    
    % Define the feedback
    Phrases.feedback = {'win', 'lose', 'nothing'};
    
    % Time scaling parameter
    timeScaling = 1;%10000;
    
    
    % -------------------------------------------------------------------------------------------------------------------------------
    %   Code
    % -------- Do NOT modify this part (if possible)
    % Add the folders containing the functions
    projectRoot = fileparts(fileparts(mfilename('fullpath')));
    addpath(fullfile(projectRoot, 'functions'));
    
    % Get the input variable(s)
    if nargin == 1
        inputPath = varargin{1};
        [inputFilePath, inputFileName, ~] = fileparts(inputPath);
        outputPath = fullfile(inputFilePath, [inputFileName, suffix, '.mat']);
    elseif nargin == 2
        inputPath = varargin{1};
        [~, inputFileName, ~] = fileparts(inputPath);
        outputPath = fullfile(varargin{2}, [inputFileName, suffix, '.mat']);
    else
        error(['Numebr of inputs: ', nargin, ' is not supported.'])
    end
    
    % Check names
    if length(Info.names) ~= length(splitByNames)
        error(['The length of Info.names (', num2str(length(Info.names)), ') is not equal to the length of splitByNames (', num2str(length(splitByNames)), ').'])
    end
    
    % Check the contrastsMatrix size
    if size(contrastsMatrix, 2) ~= length(splitByNames)
        error(['The number of columns in contrastsMatrix (', num2str(size(contrastsMatrix, 2)), ') is not equal to the length of splitByNames (', num2str(length(splitByNames)), ').'])
    end
    
    % Get the log file in a cell array
    rawData = log2numtxt(inputPath);
    
    % Split the raw data into bloks
    blockedData = cell(1,1);
    
    % Find first row where
    %   -The data starts
    %   -The experiment starts
    %firstRowData = findfirstincell(rawData(:,3), 'Pulse');
    firstRowData = 6;
    firstRowExp = findfirstincell(rawData(:,3), 'Picture');
    
    % Split the raw data into bloks
    chunkCount = 0;
    chunkInd = 1;
    for i = firstRowExp:size(rawData, 1)
        if ~isnumeric(rawData{i,4}) && contains(rawData{i,4}, Phrases.newSession)
            chunkCount = chunkCount + 1;
            chunkInd = 1;
        end
        
        % Save the row into the right chunk
        for j = 1:length(rawData(i,:))
            blockedData{chunkCount}{chunkInd,j} = rawData{i,j};
        end
        
        % Increase the index within chunks
        chunkInd = chunkInd + 1;
    end
    
    % Calculate the begining of the experiment (in time) and the TR
    startTime = rawData{firstRowExp, 5} / timeScaling;%rawData{firstRowExp-1, 5} / 10000;
    Info.TR = 2.47;%(rawData{firstRowData+1, 5} - rawData{firstRowData, 5}) / 10000;
    
    % Initialise the fields in the info struct for the results
    Info.onsets = cell(length(splitByNames), 1);
    Info.durations = cell(length(splitByNames), 1);
    Info.outcomes = cell(length(splitByNames), 1);
    Info.RT = cell(length(splitByNames), 1);
    for i = 1:length(splitByNames)
        Info.onsets{i} = zeros(1,0);
        Info.durations{i} = zeros(1,0);
        Info.outcomes{i} = zeros(1,0);
        Info.RT{i} = zeros(1,0);
    end
    
    
    % Loop through each block and collect the info we want
    for currentBlock = blockedData
        currentBlock = currentBlock{1}; % I know this is ugly but couldn't think of another way.
        
        % Decide whether it is a bad trial
        if ~isdatacontains(currentBlock, Phrases.badTrial)
            
            % Filter out the instances where they pressed the button before
            % the choice screen appeared
            % Find the time of the response picture and the actual human
            % response
            responsePictureInd = 1;%findfirstincell(currentBlock(:,4), Phrases.response);
            responseHumanInd = findfirstincell(currentBlock(:,3), 'Response');
            if responsePictureInd < responseHumanInd
                
                % Get which trial is this from the names
                nameInd = -1;
                for i = 1:length(splitByNames)
                    if isdatacontains(currentBlock(1,:), splitByNames{i})
                        nameInd = i;
                        break;
                    end
                end
                if nameInd == -1
                    continue;
                    %error('This error should not occur. This means that the response was not in the name list. Hence, you should expand your name list (splitByNames) oryou should include another word in: Phrases.badTrial')
                end
                
                % Get whether the choice is correct or incorrect
                if nameInd < 3
                    if isdatacontains(currentBlock(:,4), Phrases.feedback{1})
                        % Correct choice
                        Info.outcomes{nameInd}(end+1) = 1;
                    elseif isdatacontains(currentBlock(:,4), Phrases.feedback{2})
                        % Correct choice
                        Info.outcomes{nameInd}(end+1) = -1;
                    elseif isdatacontains(currentBlock(:,4), Phrases.feedback{3})
                        % Incorrect choice
                        nameInd = nameInd + 1;
                        Info.outcomes{nameInd}(end+1) = 0;
                    else
                        error('Not suppose to be here.')
                    end
                else
                    if isdatacontains(currentBlock(:,4), Phrases.feedback{3})
                        % Correct choice
                        nameInd = nameInd + 1;
                        Info.outcomes{nameInd}(end+1) = 1;
                    elseif isdatacontains(currentBlock(:,4), Phrases.feedback{2})
                        % Incorrect choice
                        Info.outcomes{nameInd}(end+1) = 0;
                    else
                        error('Not suppose to be here.')
                    end
                end
                
                % Calculate the onset time
                Info.onsets{nameInd}(end+1) = (currentBlock{responsePictureInd, 5} / timeScaling) - startTime;
                
                % Calculate the duration time
                Info.durations{nameInd}(end+1) = 0;
                
                % Calculate the reaction times
                Info.RT{nameInd}(end+1) = (currentBlock{responseHumanInd, 5} - currentBlock{responsePictureInd, 5}) / timeScaling;
            end
            
        end
    end
    
    % Generate the contrasts
    Info.contrasts = struct('names', {cell(size(contrastsMatrix, 1), 1)}, ...
                            'vectors', {cell(size(contrastsMatrix, 1), 1)});
    for i = 1:size(contrastsMatrix, 1)
        Info.contrasts.vectors{i} = contrastsMatrix(i, :);
        Info.contrasts.names{i} = '';
        for j = 1:size(contrastsMatrix, 2)
            if contrastsMatrix(i, j) == 1
                Info.contrasts.names{i} = [Info.contrasts.names{i}, splitByNames{j}, ' & '];
            elseif contrastsMatrix(i, j) == -1
                Info.contrasts.names{i} = [Info.contrasts.names{i}, '-', splitByNames{j}, ' & '];
            end
        end
        Info.contrasts.names{i} = Info.contrasts.names{i}(1:end-3);
    end
    
    
    % Save the file and try to get the parts of the outputPath for the
    % as our return variable
    save(outputPath, '-struct', 'Info');
    
    
    % Return
    if nargout == 1
        try
            varargout{1} = getpaths(outputPath); % Return with struct
        catch
            varargout{1} = outputPath; % Return with fullfile
        end
    elseif nargout > 0
        error(['Number of outputs: ', num2str(nargout), ' is not supported.'])
    end

end

function output = findfirstincell(data, word)
    % Finds the first instance of a word in the data cell array
    % Input:
    %   - data: the cell array where we search
    %   - word: the search word
    %
    % Output:
    %   - output: the index where the word is located
    %
    output = find(cellfun(@(x) ~isnumeric(x) && contains(x, word), data), 1, 'first');
end

function output = isdatacontains(data, words)
    % Decides whether the data contains any of the words
    % Input:
    %   - data: the cell array where we search
    %   - word: the search words in a cell
    %
    % Output:
    %   - output: True/False. If any found then true.
    %       - True: if the data somewhere contains any of the words defined
    %               in the words cell
    %       - False: else
    %
    output = any(cellfun(@(x) ~isnumeric(x) && contains(x, words), data), 'all');
end