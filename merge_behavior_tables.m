function merge_behavior_tables(inputTables, outputPath)
%MERGE_BEHAVIOR_TABLES Merge multiple trial-wise CSV tables into one file.
%
%   merge_behavior_tables(inputTables, outputPath)
%
%   Inputs
%   ------
%   inputTables : cell array of char
%       CSV files produced by logs2stan/log2stan or compatible behavioural
%       processing steps.
%   outputPath : char
%       Full path, including file name, where the merged CSV is written.
%
%   This wrapper provides a descriptive entry point for merging converted behavioural tables.

    mergestanlogs(inputTables, outputPath);
end
