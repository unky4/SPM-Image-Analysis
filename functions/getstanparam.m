function param = getstanparam(Info, paramPath, subjectNumber)
% Get a parameter produced by my Stan code (rlmcmc)
    arguments
        Info;
        paramPath (1,:) cell;
        subjectNumber (1,1) int64 = 0;
    end

    param = cell(size(paramPath));
    for i = 1:numel(paramPath)
        % Get regressor
        regressor = load(paramPath{i}).value;

        switch Info.firstLevelAnalysisSettings.point_estimate_name
            case ''
                % This is how I solved it for the DIFF study, you may need to
                % change this for other studies?
                if length(size(regressor)) == 3
                    nofSubjectsPerGroup = Info.firstLevelAnalysisSettings.nofSubjectsPerGroup;
                    regressorTmp = regressor;
                    regressor = zeros(sum(nofSubjectsPerGroup), size(regressorTmp, 2));
                    for j = 1:numel(nofSubjectsPerGroup)
                        if j == 1
                            rSel = 1:sum(nofSubjectsPerGroup(1:j));
                        else
                            rSel = (sum(nofSubjectsPerGroup(1:(j-1))) + 1):sum(nofSubjectsPerGroup(1:j));
                        end
                        regressor(rSel, :) = regressorTmp(1:nofSubjectsPerGroup(j), :, j);
                    end
                end 
            otherwise
                if length(size(regressor)) == 5
                    nofSubjectsPerGroup = Info.firstLevelAnalysisSettings.nofSubjectsPerGroup;
                    regressorTmp = regressor;
                    regressor = zeros(size(regressorTmp, 1), size(regressorTmp, 2), sum(nofSubjectsPerGroup), size(regressorTmp, 4));
                    for j = 1:numel(nofSubjectsPerGroup)
                        if j == 1
                            rSel = 1:sum(nofSubjectsPerGroup(1:j));
                        else
                            rSel = (sum(nofSubjectsPerGroup(1:(j-1))) + 1):sum(nofSubjectsPerGroup(1:j));
                        end
                        regressor(:, :, rSel, :) = regressorTmp(:, :, 1:nofSubjectsPerGroup(j), :, j);
                    end
                end
        end

        % Get the point estimate
        switch Info.firstLevelAnalysisSettings.point_estimate_name
            case ''
                
            case 'mean'
                regressor = squeeze(mean(regressor, [1, 2]));
            case 'median'
                regressor = squeeze(median(regressor, [1, 2]));
            case 'mode'
                error('Not implemented!')
                regressor = squeeze(mode(regressor, [1, 2]));
            otherwise
                error('Wrong point_estimate_name!')
        end


        % Get regressor for the subject
        if subjectNumber == 0
            param{i} = regressor;
        else
            param{i} = regressor(subjectNumber, :);
        end
    end
end
