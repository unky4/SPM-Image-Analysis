function matlabbatch = secondlevelanalysisanova_job(Info, conFilesGrouped, groupNames)
% Custom SPM12 anova job
%
%   Inputs:
%       - Info: The Info structure
%       - conFilesGrouped: Grouped first-level analysis con files
%
%   Outputs:
%       - matlabbatch: SPM12 created batch variable
%
%   Note: SPM12 has to be started before you call this function
%         Recommend to do this by: spm('Defaults', 'fMRI');
%
%   Note: I run the processes individually because this way it is easier to
%         reference the images in the next step.
%         You CANNOT use dependency in the next step since we need to
%         neglect the first n images which is impossible to do with
%         dependecy because spm just ignores these images and create a new
%         images with the same size.

    matlabbatch{1}.spm.stats.factorial_design.dir = {Info.paths.secondlaAnovaSave.fullPath};
    for i = 1:numel(conFilesGrouped)
        matlabbatch{1}.spm.stats.factorial_design.des.anova.icell(i).scans = conFilesGrouped{i};
    end
    matlabbatch{1}.spm.stats.factorial_design.des.anova.dept = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.anova.variance = 1;
    matlabbatch{1}.spm.stats.factorial_design.des.anova.gmsca = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.anova.ancova = 0;
    matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 0;
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;
    
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep('Factorial design specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
    
    matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    for i = 1:numel(conFilesGrouped)
        matlabbatch{3}.spm.stats.con.consess{i}.tcon.name = [groupNames{i}, ' > rest'];
        weight = -1/(numel(conFilesGrouped)-1) * ones(1, numel(conFilesGrouped));
        weight(i) = 1;
        matlabbatch{3}.spm.stats.con.consess{i}.tcon.weights = weight;
        matlabbatch{3}.spm.stats.con.consess{i}.tcon.sessrep = 'none';
    end
    for i = 1:numel(conFilesGrouped)
        matlabbatch{3}.spm.stats.con.consess{i+numel(conFilesGrouped)}.tcon.name = [groupNames{i}, ' < rest'];
        weight = 1/(numel(conFilesGrouped)-1) * ones(1, numel(conFilesGrouped));
        weight(i) = -1;
        matlabbatch{3}.spm.stats.con.consess{i+numel(conFilesGrouped)}.tcon.weights = weight;
        matlabbatch{3}.spm.stats.con.consess{i+numel(conFilesGrouped)}.tcon.sessrep = 'none';
    end
    matlabbatch{3}.spm.stats.con.delete = 0;
end

