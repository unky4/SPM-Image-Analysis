function subjectIDs = dividepatients(subjectIDs, nofGroups)
% Divides a list of patients into n groups
%
%   Inputs:
%       - subjectIDs: List of subject IDs (in cell)
%       - nofGroups: Number of goups you want to divide the IDs
%
    padding = (nofGroups - mod(numel(subjectIDs), nofGroups));
    padding = padding * sign(padding);
    subjectIDs(end+1:end+padding) = cell(1,1);
    subjectIDs = reshape(subjectIDs, nofGroups, [])';
end