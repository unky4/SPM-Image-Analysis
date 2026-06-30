function cocorfisher(mainDir, analysisName, groupFileName, correlationFileName, correlationCoefficientNames)
% Calculates the statistic significance between 2 groups of images of independent correlation coefficients
%
%   Inputs:
%       - 
%
%   Outputs:
%       - None
%
%   Usage:

    % Generate paths
    imgDir = fullfile(mainDir, analysisName, 'files_for_second_level');
    groupPath = fullfile(mainDir, groupFileName);
    correlationPath = fullfile(mainDir, correlationFileName);
    outputDir = fullfile(mainDir, analysisName, 'Correlation_group_level_differences');
    if exist(outputDir, 'dir') == 0
        mkdir(outputDir);
    end

    % Get data
    Groups = getgroups(imgDir, groupPath, correlationPath, correlationCoefficientNames);
    
    % Loop through all correlation coefficient names
    for i = 1:numel(correlationCoefficientNames)
        correlationCoefficientName = correlationCoefficientNames{i};
        
        % Loop throuh the Group combinations
        combinations = nchoosek(1:numel(Groups.groupNames), 2);
        for j = 1:size(combinations, 1)
            % For readability
            group1Name = Groups.groupNames{combinations(j, 1)};
            group2Name = Groups.groupNames{combinations(j, 2)};
            r1 = Groups.PearsonR.(correlationCoefficientName).(group1Name);
            r2 = Groups.PearsonR.(correlationCoefficientName).(group2Name);
            n1 = Groups.SampleSize.(correlationCoefficientName).(group1Name);
            n2 = Groups.SampleSize.(correlationCoefficientName).(group2Name);

            % Get correaltion coeff and p-value
            [z, p] = independent_ficher_corr(r1, r2, n1, n2, true);

            % Corrected FDR P values
            pFDR = nan(size(p));
            pFDR(p <= 0.05) = p(p <= 0.05);
            pFDR = spm_P_FDR(pFDR);

            % Create mask for < 0.05 regions
            fdrMask = pFDR <= 0.05;

            % Mask the Z-values
            zFdrMasked = z .* fdrMask;

            % Output folder
            outputDirCorr = fullfile(outputDir, correlationCoefficientName);
            if exist(outputDirCorr, 'dir') == 0
                mkdir(outputDirCorr);
            end

            % Save
            info = Groups.Images.Info.(group1Name){1};
            niftiwrite(z, fullfile(outputDirCorr, [group1Name, '_', group2Name, '_z.nii']), info);
            niftiwrite(p, fullfile(outputDirCorr, [group1Name, '_', group2Name, '_p.nii']), info);
            niftiwrite(zFdrMasked, fullfile(outputDirCorr, [group1Name, '_', group2Name, '_z_fdr_masked_0_05.nii']), info);
            niftiwrite(single(pFDR), fullfile(outputDirCorr, [group1Name, '_', group2Name, '_p_fdr.nii']), info);
        end
    end
end

function Groups = getgroups(imgDir, groupPath, correlationPath, correlationCoefficientNames)
% Get all image path and group names into a struct
    
    % Read groups file and correlation file
    groupInfo = readtable(groupPath);
    correlationCoeffs = readtable(correlationPath);
    correlationCoeffs = correlationCoeffs(:, cat(1, {'ID'}, correlationCoefficientNames));
    groupInfo.group_name = cellfun(@(x) replace(x, '-', '_'), groupInfo.group_name, 'UniformOutput',false);


    % Get the unique group neames
    Groups = struct('groupNames', {unique(groupInfo.group_name)});

    % Get the image paths, image and info for each group
    Groups.Images = struct('Paths', struct(), 'Data', struct(), 'Info', struct());
    for i = 1:numel(Groups.groupNames)
        Groups.Images.Paths.(Groups.groupNames{i}) = cell(0, 1);
        Groups.Images.Data.(Groups.groupNames{i}) = cell(0, 1);
        Groups.Images.Info.(Groups.groupNames{i}) = cell(0, 1);
        
    end
    for i = 1:numel(correlationCoefficientNames)
        Groups.Scores.(correlationCoefficientNames{i}) = struct();
        Groups.ScoresNonNanIndicators.(correlationCoefficientNames{i}) = struct();
        for j = 1:numel(Groups.groupNames)
            Groups.Scores.(correlationCoefficientNames{i}).(Groups.groupNames{j}) = zeros(0);
            Groups.ScoresNonNanIndicators.(correlationCoefficientNames{i}).(Groups.groupNames{j}) = false(0);
        end
    end
    for i = 1:height(groupInfo)
        ID = groupInfo.ID{i};
        imgPath = fullfile(imgDir, [ID, '_con_0001.nii']);

        % Find index of the ID in the correlation table
        [~, index] = ismember(ID, correlationCoeffs.ID);

        % Get scores
        scoresT = correlationCoeffs(index, correlationCoefficientNames);
        scores = struct();
        for j = 1:numel(correlationCoefficientNames)
            score = scoresT.(correlationCoefficientNames{j});
            scores.(correlationCoefficientNames{j}) = score;
        end

        if isfile(imgPath)
            Groups.Images.Paths.(groupInfo.group_name{i}){end+1, 1} = imgPath;
            data = niftiread(imgPath);
            Groups.Images.Data.(groupInfo.group_name{i}){end+1, 1} = reshape(data, [1, size(data)]);
            Groups.Images.Info.(groupInfo.group_name{i}){end+1, 1} = niftiinfo(imgPath);
            
            for j = 1:numel(correlationCoefficientNames)
                Groups.Scores.(correlationCoefficientNames{j}).(groupInfo.group_name{i})(end+1, 1) = scores.(correlationCoefficientNames{j});
                Groups.ScoresNonNanIndicators.(correlationCoefficientNames{j}).(groupInfo.group_name{i})(end+1, 1) = ~isnan(scores.(correlationCoefficientNames{j}));
            end
        end
    end

    % Make data to 1 matrix
    for i = 1:numel(Groups.groupNames)
        Groups.Images.Data.(Groups.groupNames{i}) = cell2mat(Groups.Images.Data.(Groups.groupNames{i}));
    end

    % Pearson correlations
    Groups.PearsonR = struct();
    for j = 1:numel(correlationCoefficientNames)
        Groups.PearsonR.(correlationCoefficientNames{j}) = struct();
        for i = 1:numel(Groups.groupNames)
            images = Groups.Images.Data.(Groups.groupNames{i});
            scores = Groups.Scores.(correlationCoefficientNames{j}).(Groups.groupNames{i});
            scoresNonNanIndicators = Groups.ScoresNonNanIndicators.(correlationCoefficientNames{j}).(Groups.groupNames{i});
            images = images(scoresNonNanIndicators, :, :, :);
            scores = scores(scoresNonNanIndicators);
            r = pearsoncorrelation(images, scores);
            Groups.PearsonR.(correlationCoefficientNames{j}).(Groups.groupNames{i}) = r;
        end
    end

    % Get sample sizes
    Groups.SampleSize = struct();
    for j = 1:numel(correlationCoefficientNames)
        Groups.SampleSize.(correlationCoefficientNames{j}) = struct();
        for i = 1:numel(Groups.groupNames)
            Groups.SampleSize.(correlationCoefficientNames{j}).(Groups.groupNames{i}) = sum(Groups.ScoresNonNanIndicators.(correlationCoefficientNames{j}).(Groups.groupNames{i}));
        end
    end
end

function r = pearsoncorrelation(images, scores)
% Calcualtes the pearson correlation for a group and a correlation
% coefficient
    % Get original image size
    imagesSize = size(images);
    n = imagesSize(1);
    imagesSize = imagesSize(2:end);

    % convert images
    imgs = reshape(images, n, prod(imagesSize));

    % Calculate pearson r
    r = corr(imgs, scores);

    % Reshape back to image size
    r = reshape(r, imagesSize);
end


function [z, p] = independent_ficher_corr(r1, r2, n1, n2, is2Tailed)
% Calculates the z-score and p-value for the difference between the 2
% gourps' correlation coeffs

    % Fisher transformation
    r1F = 0.5 * log((1 + r1) ./ (1 - r1));
    r2F = 0.5 * log((1 + r2) ./ (1 - r2));

    % Standard error of the difference
    seDiff = sqrt(1/(n1 - 3) + 1/(n2 - 3));

    % Calculte z-score and p-value (for each voxel)
    z = abs((r1F - r2F) ./ seDiff);
    p = (1 - normcdf(z));
    
    % For 2 tailed tests
    if is2Tailed
        p = 2*p;
    end
end