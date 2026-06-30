function secondlevelanalysis(analysisDescription, varargin)
% Performes the second level analysis of fMRI scans.
%
%   Input pairs (second value is the default value):
%
%       - 'settingsFilePath', 'settings.YAML':
%               Path to the YAML file containing the settings
%
%       - 'jobFunction1STTest', 'secondlevelanalysis1sttest_job':
%               SPM12 second-level analysis 1-sample t-test job function
%               name (without .m)
%               To create one see the default custom
%               secondlevelanalysisttest_job function.
%
%       - 'jobFunctionRegression', 'secondlevelanalysisregression_job'
%               SPM12 second-level analysis regression job function name
%               (without .m)
%               To create one see the default custom
%               secondlevelanalysisregression_job function.
%
%       - 'regressionParamsPath', ''
%               Path to the regression csv file
%               If not defined no second-level regression analyis will be
%               conducted
%               See example of such file in regression_params.csv
%
%       - 'jobFunction2STTest', 'secondlevelanalysis2sttest_job':
%               SPM12 second-level analysis 2-smaple t-test job function
%               name (without .m)
%               To create one see the default custom
%               secondlevelanalysis2sttest_job function.
%
%       - 'groups2stestPath', '':
%               Path to the groups csv file
%               If not defined no second-level 2-sample analyis will be
%               conducted
%
%       - 'jobFunctionAnova', 'secondlevelanalysisanova_job':
%               SPM12 anova job function name (without .m)
%               To create one see the default custom
%               secondlevelanalysisanova_job function.
%
%       - 'anovaGroupsPath', '':
%               Path to the groups for anova csv file
%               If not defined no anova analyis will be conducted
%
%   Usage:
%       - secondlevelanalysis()
%               - Uses all default values
%
%       - secondlevelanalysis('settingsFilePath', 'custom_settings.YAML', ...
%                             'jobFunction', 'custom_secondlevelanalysis_job', ...
%                             'nofNodesToUse', 4, ...
%                             'nodeID', 2)
%               - Uses the settings located in the custom_settings.YAML file
%               - Uses the secondlevelanalysis function called
%                 custom_secondlevelanalysis_job
%               - Splits the data between 4 nodes
%               - Runs the second-level analysis on the 2nd node
    
    spmia_setup_paths(mfilename('fullpath'));

    % Parse input or get defualts
    InputArgs = parseinput('secondlevelanalysis', varargin{:});


    % Load settings
    Settings = getsettings(InputArgs.settingsFilePath);


    % Start SPM12
    if ~isempty(Settings.spmPath)
        addpath(Settings.spmPath);
        addpath(fullfile(Settings.spmPath, 'matlabbatch'));
    end
    global defaults
    spm('Defaults', 'fMRI');
    defaults.stats.resmem = Settings.resmem;
    defaults.stats.maxmem = 5000000000;
    
    % Do second-level analysis
    secondlevelanalysis_(Settings, ...
                         InputArgs.jobFunction1STTest, ...
                         InputArgs.jobFunctionRegression, ...
                         InputArgs.regressionParamsPath, ...
                         InputArgs.jobFunction2STTest, ...
                         InputArgs.groups2stestPath, ...
                         InputArgs.jobFunctionAnova, ...
                         InputArgs.anovaGroupsPath, ...
                         analysisDescription);
end


function secondlevelanalysis_(Settings, jobFunction1STTest, jobFunctionRegression, regressionParamsPath, jobFunction2STTest, groups2stestPath, jobFunctionAnova, anovaGroupsPath, analysisDescription)
% The main Second-level analysis code
%
    subjectIDs = getsubjects(Settings, 1, 1);
    subjectIDs = subjectIDs(cellfun(@(x) ~isempty(x), subjectIDs, 'UniformOutput', true));

    for subjInd = 1:numel(subjectIDs)
        % Initialise/Load Info structure where we save most analyis related
        % information
        Info = getinfo(subjectIDs{subjInd}, Settings);

        % Create final folder
        Info.paths.secondlaFinalSave = getpaths(fullfile(Info.paths.saveRoot.fullPath, ['000_', analysisDescription]));
        createdir(Info.paths.secondlaFinalSave.fullPath);
        
        % Copy the files that we need from first-level analysis into a
        % seperate fodler
        Info = copyfirstlevelanalysisneededfiles(Info);
    end


    % 1-sample T-test
    for i = 1:numel(groups2stestPath)
        Info = secondlevelanalysis_1sttest(Info, jobFunction1STTest, groups2stestPath{i});
    end

    if isfield(Info, 'firstLevelAnalysisSettings') && isfield(Info.firstLevelAnalysisSettings.contrasts.x1, 'type') && strcmp(Info.firstLevelAnalysisSettings.contrasts.x1.type, "F")
        % For F contrasts for now just skip the rest
        A = 0;
    else
        % Regressions
        if ~isempty(regressionParamsPath)
            Info.paths.regressionParamsPath = getpaths(fullfile(regressionParamsPath));
            Info = secondlevelanalysis_regressions(Info, jobFunctionRegression);
        end
    
    
        % 2-sample T-test
        if ~isempty(groups2stestPath{1})
            for i = 1:numel(groups2stestPath)
                Info.paths.groups2stestPath = getpaths(fullfile(groups2stestPath{i}));
                Info = secondlevelanalysis_2sttest(Info, jobFunction2STTest);
            end
        end
    
    
        % Anova
        if ~isempty(anovaGroupsPath)
            Info.paths.anovaGroupsPath = getpaths(fullfile(anovaGroupsPath));
            Info = secondlevelanalysis_anova(Info, jobFunctionAnova);
        end
    end

    
    % Copy the whole analysis into a new folder named analysisDescription
    movefirstlevelanalysis(Info)

    cd(Info.paths.saveRoot.fullPath);
end


function Info = copyfirstlevelanalysisneededfiles(Info)
    % Create save folder
    Info.paths.secondlaFilesForSecondLevelSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, 'files_for_second_level'));
    createdir(Info.paths.secondlaFilesForSecondLevelSave.fullPath)
    
    imgTypeName = 'con_0001';
    if isfield(Info, 'firstLevelAnalysisSettings') && isfield(Info.firstLevelAnalysisSettings.contrasts.x1, 'type') && strcmp(Info.firstLevelAnalysisSettings.contrasts.x1.type, "F")
        imgTypeName = 'ess_0001';
    end
    % We only need the con and mask files from the first level analysis
    % Get the con file names
    conNames = dir(Info.paths.firstlaSave.fullPath);
    conNames = {conNames.name}';
    conNames = conNames(cellfun(@(x) contains(x, imgTypeName), conNames));
    
    % Copy and rename the files
    if isfile(fullfile(Info.paths.firstlaSave.fullPath, 'mask.img')) && any(isfile(fullfile(Info.paths.firstlaSave.fullPath, conNames)))
        for i = 1:length(conNames)
            copyfile(fullfile(Info.paths.firstlaSave.fullPath, conNames{i}), fullfile(Info.paths.secondlaFilesForSecondLevelSave.fullPath, [Info.ID, '_', conNames{i}]));
        end
        copyfile(fullfile(Info.paths.firstlaSave.fullPath, 'mask.img'), fullfile(Info.paths.secondlaFilesForSecondLevelSave.fullPath, [Info.ID, '_mask.img']));
        copyfile(fullfile(Info.paths.firstlaSave.fullPath, 'mask.hdr'), fullfile(Info.paths.secondlaFilesForSecondLevelSave.fullPath, [Info.ID, '_mask.hdr']));
    
    elseif isfile(fullfile(Info.paths.firstlaSave.fullPath, 'mask.nii')) && any(isfile(fullfile(Info.paths.firstlaSave.fullPath, conNames)))
        for i = 1:length(conNames)
            copyfile(fullfile(Info.paths.firstlaSave.fullPath, conNames{i}), fullfile(Info.paths.secondlaFilesForSecondLevelSave.fullPath, [Info.ID, '_', conNames{i}]));
        end
        copyfile(fullfile(Info.paths.firstlaSave.fullPath, 'mask.nii'), fullfile(Info.paths.secondlaFilesForSecondLevelSave.fullPath, [Info.ID, '_mask.nii']));
    end
end


function Info = secondlevelanalysis_1sttest(Info, jobFunction, groupsPath)
% Second-level 1-sample T-test
    % Collect the first level analysis con files
    conFiles = cell(1, 1);
    conFiles{1} = getconfiles(Info.paths.secondlaFilesForSecondLevelSave.fullPath);
    groupNames = {'All_Groups'};

    if ~isempty(groupsPath)
        % Load the groups and split the con files
        groups = readtable(groupsPath);
        groupsValues = zeros(size(conFiles{1}));
        groupNamesPerSubj = cell(size(conFiles{1}));
        for i = 1:size(groups, 1)
            for j = 1:length(conFiles{1})
                [~, conName, ~] = fileparts(conFiles{1}{j});
                conName = regexprep(conName, '_con_.*', '');
                conName = regexprep(conName, '_ess_.*', '');
                if strcmp(groups.ID{i}, conName)
                    groupsValues(j) = groups.group_id(i);
                    groupNamesPerSubj{j} = groups.group_name{i};
                end
            end
        end
        for i = 1:max(groupsValues)
            conFiles{i+1} = conFiles{1}(groupsValues==i);
            if numel(unique(groupNamesPerSubj(groupsValues==i))) > 1
                error('group_name and group_id does not match!');
            end
            tmp = unique(groupNamesPerSubj(groupsValues==i)); % fu matlab
            groupNames{i+1} = tmp{1};
        end
    end

    for i = 1:numel(conFiles)
        % Create save folder
        folderNameCurrent = ['second_level_1_sample_t_test_', groupNames{i}];
        if isfolder(fullfile(Info.paths.secondlaFinalSave.fullPath, folderNameCurrent))
            continue;
        end
        Info.paths.secondla1sTtestSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, folderNameCurrent));
        createdir(Info.paths.secondla1sTtestSave.fullPath)
    
    
        % Get spm job
        matlabbatch = jobFunction(Info, conFiles{i}, groupNames{i});

        % Run
        runCounter = 0;
        isSuccessful = false;
        while runCounter <= 10 && ~isSuccessful
            try 
                spm_jobman('initcfg');
                spm_jobman('run', matlabbatch);
                isSuccessful = true;
            catch
                runCounter = runCounter + 1;
                try
                    rmdir(Info.paths.secondla1sTtestSave.fullPath, 's');
                    createdir(Info.paths.secondla1sTtestSave.fullPath)
                catch
                    continue;
                end
            end
        end

        if ~isSuccessful
            secondla1sTtestSaveFullPath = Info.paths.secondla1sTtestSave.fullPath;
            Info.paths.secondla1sTtestSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, [folderNameCurrent, '_error']));
            movefile(secondla1sTtestSaveFullPath, Info.paths.secondla1sTtestSave.fullPath);
            try
                rmdir(secondla1sTtestSaveFullPath, 's');
            catch
                A = 0;
            end
        end

        
        
        % % Run
        % try
        %     spm_jobman('initcfg');
        %     spm_jobman('run', matlabbatch);
        % catch emsg
        %     secondla1sTtestSaveFullPath = Info.paths.secondla1sTtestSave.fullPath;
        %     Info.paths.secondla1sTtestSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, [folderNameCurrent, '_error']));
        %     movefile(secondla1sTtestSaveFullPath, Info.paths.secondla1sTtestSave.fullPath);
        %     try
        %         rmdir(secondla1sTtestSaveFullPath, 's');
        %     catch
        %         A = 0;
        %     end
        % end
    end
end


function Info = secondlevelanalysis_regressions(Info, jobFunction)
% Second-level regressions
    % Load the regression parameters
    regressionParameters = readtable(Info.paths.regressionParamsPath.fullPath);
    Info.regressionParameterNames = regressionParameters.Properties.VariableNames(2:end);
    

    % Collect the first level analysis con files
    conFiles = getconfiles(Info.paths.secondlaFilesForSecondLevelSave.fullPath);

    
    for ind = 1:numel(Info.regressionParameterNames)
        regressorName = Info.regressionParameterNames{ind};

        % Create the output folder
        folderNameCurrent = ['second_level_regression_', regressorName];
        Info.paths.(['secondlaRegressor', regressorName, 'Save']) = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, folderNameCurrent));
        createdir(Info.paths.(['secondlaRegressor', regressorName, 'Save']).fullPath)


        % Get the regressor values
        regressorValues = zeros(0, 1);
        conFilesCurrent = cell(0, 1);
        for i = 1:size(regressionParameters, 1)
            for j = 1:length(conFiles)
                [~, conName, ~] = fileparts(conFiles{j});
                conName = regexprep(conName, '_con_.*', '');
                conName = regexprep(conName, '_ess_.*', '');
                if strcmp(regressionParameters.ID{i}, conName)
                    regressorValue = regressionParameters.(regressorName)(i);
                    if ~isnan(regressorValue)
                        regressorValues(end+1, 1) = regressorValue;
                        conFilesCurrent{end+1, 1} = conFiles{j};
                    end
                end
            end
        end
        

        % Get spm job
        matlabbatch = jobFunction(Info, conFilesCurrent, regressorName, regressorValues);

        % Run
        runCounter = 0;
        isSuccessful = false;
        while runCounter <= 10 && ~isSuccessful
            try 
                spm_jobman('initcfg');
                spm_jobman('run', matlabbatch);
                isSuccessful = true;
            catch
                runCounter = runCounter + 1;
                try
                    rmdir(Info.paths.(['secondlaRegressor', regressorName, 'Save']).fullPath, 's');
                    createdir(Info.paths.(['secondlaRegressor', regressorName, 'Save']).fullPath)
                catch
                    continue;
                end
            end
        end

        if ~isSuccessful
            secondlaRegressorFullPath = Info.paths.(['secondlaRegressor', regressorName, 'Save']).fullPath;
            Info.paths.(['secondlaRegressor', regressorName, 'Save']) = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, [folderNameCurrent, '_error']));
            movefile(secondlaRegressorFullPath, Info.paths.(['secondlaRegressor', regressorName, 'Save']).fullPath);
            try
                rmdir(secondlaRegressorFullPath, 's');
            catch
                A = 0;
            end
        end

        % % Run
        % try
        %     spm_jobman('initcfg');
        %     spm_jobman('run', matlabbatch);
        % catch
        %     secondlaRegressorFullPath = Info.paths.(['secondlaRegressor', regressorName, 'Save']).fullPath;
        %     Info.paths.(['secondlaRegressor', regressorName, 'Save']) = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, [folderNameCurrent, '_error']));
        %     movefile(secondlaRegressorFullPath, Info.paths.(['secondlaRegressor', regressorName, 'Save']).fullPath);
        %     try
        %         rmdir(secondlaRegressorFullPath, 's');
        %     catch
        %         A = 0;
        %     end
        % end
    end
end


function Info = secondlevelanalysis_2sttest(Info, jobFunction)
% Second-level 2-sample T-test
    
    % Collect the first level analysis con files
    conFiles = getconfiles(Info.paths.secondlaFilesForSecondLevelSave.fullPath);

    % Load the groups and split the con files
    groups = readtable(Info.paths.groups2stestPath.fullPath);
    groupsValues = zeros(size(conFiles));
    groupNamesPerSubj = cell(size(conFiles{1}));
    for i = 1:size(groups, 1)
        for j = 1:length(conFiles)
            [~, conName, ~] = fileparts(conFiles{j});
            conName = regexprep(conName, '_con_.*', '');
            conName = regexprep(conName, '_ess_.*', '');
            if strcmp(groups.ID{i}, conName)
                groupsValues(j) = groups.group_id(i);
                groupNamesPerSubj{j} = groups.group_name{i};
            end
        end
    end
    conFilesGrouped = cell(max(groupsValues), 1);
    groupNames = cell(max(groupsValues), 1);
    for i = 1:max(groupsValues)
        conFilesGrouped{i} = conFiles(groupsValues==i);
        if numel(unique(groupNamesPerSubj(groupsValues==i))) > 1
            error('group_name and group_id does not match!');
        end
        tmp = unique(groupNamesPerSubj(groupsValues==i));
        groupNames{i} = tmp{1};
    end

    % Possible combinations
    combinations = nchoosek(1:max(groupsValues), 2);
    
    for i = 1:size(combinations, 1)
        % Get the 2 gorups
        conFilesGroupedCurrent = cell(2, 1);
        groupNamesCurrent = cell(2, 1);
        conFilesGroupedCurrent{1} = conFilesGrouped{combinations(i, 1)};
        conFilesGroupedCurrent{2} = conFilesGrouped{combinations(i, 2)};
        groupNamesCurrent{1} = groupNames{combinations(i, 1)};
        groupNamesCurrent{2} = groupNames{combinations(i, 2)};


        % Create save folder
        folderNameCurrent = ['second_level_2_sample_t_test_', groupNamesCurrent{1}, '_vs_', groupNamesCurrent{2}];
        Info.paths.secondla2sTtestSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, folderNameCurrent));
        createdir(Info.paths.secondla2sTtestSave.fullPath)
        

        % Get spm job
        matlabbatch = jobFunction(Info, conFilesGroupedCurrent, groupNamesCurrent);
        
    
        % Run
        runCounter = 0;
        isSuccessful = false;
        while runCounter <= 10 && ~isSuccessful
            try 
                spm_jobman('initcfg');
                spm_jobman('run', matlabbatch);
                isSuccessful = true;
            catch
                runCounter = runCounter + 1;
                try
                    rmdir(Info.paths.secondla2sTtestSave.fullPath, 's');
                    createdir(Info.paths.secondla2sTtestSave.fullPath)
                catch
                    continue;
                end
            end
        end

        if ~isSuccessful
            secondla2sTtestSaveFullPath = Info.paths.secondla2sTtestSave.fullPath;
            Info.paths.secondla2sTtestSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, [folderNameCurrent, '_error']));
            movefile(secondla2sTtestSaveFullPath, Info.paths.secondla2sTtestSave.fullPath);
            try
                rmdir(secondla2sTtestSaveFullPath, 's');
            catch
                continue;
            end
        end



        % try 
        %     spm_jobman('initcfg');
        %     spm_jobman('run', matlabbatch);
        % catch
        %     secondla2sTtestSaveFullPath = Info.paths.secondla2sTtestSave.fullPath;
        %     Info.paths.secondla2sTtestSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, [folderNameCurrent, '_error']));
        %     movefile(secondla2sTtestSaveFullPath, Info.paths.secondla2sTtestSave.fullPath);
        %     try
        %         rmdir(secondla2sTtestSaveFullPath, 's');
        %     catch
        %         A = 0;
        %     end
        % end
    end
end


function Info = secondlevelanalysis_anova(Info, jobFunction)
    % Create save folder
    folderNameCurrent = 'anova';
    Info.paths.secondlaAnovaSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, folderNameCurrent));
    createdir(Info.paths.secondlaAnovaSave.fullPath)
    
    % Collect the first level analysis con files
    conFiles = getconfiles(Info.paths.secondlaFilesForSecondLevelSave.fullPath);

    % Load the groups and split the con files
    groups = readtable(Info.paths.anovaGroupsPath.fullPath);
    groupsValues = zeros(size(conFiles));
    groupNamesPerSubj = cell(size(conFiles{1}));
    for i = 1:size(groups, 1)
        for j = 1:length(conFiles)
            [~, conName, ~] = fileparts(conFiles{j});
            conName = regexprep(conName, '_con_.*', '');
            conName = regexprep(conName, '_ess_.*', '');
            if strcmp(groups.ID{i}, conName)
                groupsValues(j) = groups.group_id(i);
                groupNamesPerSubj{j} = groups.group_name{i};
            end
        end
    end

    conFilesGrouped = cell(max(groupsValues), 1);
    groupNames = cell(max(groupsValues), 1);
    for i = 1:max(groupsValues)
        conFilesGrouped{i} = conFiles(groupsValues==i);
        if numel(unique(groupNamesPerSubj(groupsValues==i))) > 1
            error('group_name and group_id does not match!');
        end
        tmp = unique(groupNamesPerSubj(groupsValues==i));
        groupNames{i} = tmp{1};
    end
    

    % Get spm job
    matlabbatch = jobFunction(Info, conFilesGrouped, groupNames);
    
    % Run
    runCounter = 0;
    isSuccessful = false;
    while runCounter <= 10 && ~isSuccessful
        try 
            spm_jobman('initcfg');
            spm_jobman('run', matlabbatch);
            isSuccessful = true;
        catch
            runCounter = runCounter + 1;
            try
                rmdir(Info.paths.secondlaAnovaSave.fullPath, 's');
                createdir(Info.paths.secondlaAnovaSave.fullPath)
            catch
                continue;
            end
        end
    end

    if ~isSuccessful
        secondlaAnovaSaveFullPath = Info.paths.secondlaAnovaSave.fullPath;
        Info.paths.secondlaAnovaSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, [folderNameCurrent, '_error']));
        movefile(secondlaAnovaSaveFullPath, Info.paths.secondlaAnovaSave.fullPath);
        try
            rmdir(secondlaAnovaSaveFullPath, 's');
        catch
            A = 0;
        end
    end

    % % Run
    % try
    %     spm_jobman('initcfg');
    %     spm_jobman('run', matlabbatch);
    % catch
    %     secondlaAnovaSaveFullPath = Info.paths.secondlaAnovaSave.fullPath;
    %     Info.paths.secondlaAnovaSave = getpaths(fullfile(Info.paths.secondlaFinalSave.fullPath, [folderNameCurrent, '_error']));
    %     movefile(secondlaAnovaSaveFullPath, Info.paths.secondlaAnovaSave.fullPath);
    %     try
    %         rmdir(secondlaAnovaSaveFullPath, 's');
    %     catch
    %         A = 0;
    %     end
    % end
end


function movefirstlevelanalysis(Info)
% Move the first level analysis folder into the second level analysis
% folder
    
    status = 0;
    counter = 0;
    while counter < 10 && status == 0
        status = movefile(Info.paths.firstlaSave.path, Info.paths.secondlaFinalSave.fullPath);
    end
    if counter >= 10
        error('Could not move the first-level analysis folder.');
    end
end





