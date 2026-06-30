function subjectIDs = bids_get_subjects(Settings)
%BIDS_GET_SUBJECTS Return subject IDs from a BIDS dataset.
%
%   subjectIDs = bids_get_subjects(Settings)
%
%   The function scans Settings.bids.root for sub-* folders and returns the
%   subject labels without the sub- prefix. This keeps downstream Info.ID
%   values compatible with the rest of the toolbox while allowing the imaging source
%   data to follow BIDS conventions.

    bidsRoot = Settings.bids.root;
    assert(isfolder(bidsRoot), 'BIDS root does not exist: %s', bidsRoot);

    subjectDirs = dir(fullfile(bidsRoot, 'sub-*'));
    subjectDirs = subjectDirs([subjectDirs.isdir]);
    subjectIDs = regexprep({subjectDirs.name}', '^sub-', '');
    subjectIDs = sort(subjectIDs);

    if isfield(Settings.bids, 'subject_labels') && ~isempty(Settings.bids.subject_labels)
        requested = Settings.bids.subject_labels;
    elseif isfield(Settings.bids, 'subjects') && ~isempty(Settings.bids.subjects)
        requested = Settings.bids.subjects;
    else
        requested = {};
    end

    if ~isempty(requested)
        if ischar(requested)
            requested = {requested};
        end
        requested = regexprep(requested, '^sub-', '');
        subjectIDs = subjectIDs(ismember(subjectIDs, requested));
    end
end
