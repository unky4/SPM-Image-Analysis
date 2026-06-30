function varargout = logs2stan(logDir, varargin)
%LOGS2STAN Convert Presentation log files into trial-wise analysis tables.
%
%   data = logs2stan(logDir, 'settingsFilePath', settingsPath)
%   logs2stan(logDir, 'settingsFilePath', settingsPath, 'outputDir', outputDir)
%
%   This wrapper provides a descriptive entry point for converting Presentation logs.
%   It accepts the same inputs and returns/saves the same table as LOG2STAN.

    [varargout{1:nargout}] = log2stan(logDir, varargin{:});
end
