function subjectIDs = getsubjects(Settings, nofGroups, groupID)
%GETSUBJECTS Return subject IDs for the requested processing partition.
%
%   subjectIDs = getsubjects(Settings, nofGroups, groupID)
%
%   BIDS subject discovery is used when Settings.bids.enabled is true.
%   Flat-folder discovery is used when BIDS is disabled.

    if isfield(Settings, 'bids') && isfield(Settings.bids, 'enabled') && Settings.bids.enabled
        subjectIDs = bids_get_subjects(Settings);
    else
        subjectIDs = dir(Settings.functionalPath);
        subjectIDs = {subjectIDs.name}';
        subjectIDs(~contains(subjectIDs, '.nii')) = [];
        subjectIDs = strrep(subjectIDs, [Settings.functionalSuffix, '.nii'], '');

        if Settings.nofSessions > 1
            for i = 1:length(subjectIDs)
                startInd = strfind(subjectIDs(i), Settings.sessionSuffix);
                subjectIDs{i} = subjectIDs{i}(1:startInd{1}-1);
            end
            subjectIDs = unique(subjectIDs);
        end
    end

    patientIDsSavePath = fullfile(fullfile(Settings.saveRoot), 'patientIDs.mat');
    if ~(exist(patientIDsSavePath, 'file') == 2)
        save(patientIDsSavePath, 'subjectIDs');
    end

    padding = (nofGroups - mod(numel(subjectIDs), nofGroups));
    padding = padding * sign(padding);
    subjectIDs(end+1:end+padding) = cell(1,1);
    subjectIDs = reshape(subjectIDs, nofGroups, [])';
    subjectIDs = subjectIDs(:, groupID);
end
