function matlabbatch = secondlevelanalysis2sttest_spm8_job(Info, conFilesGrouped, groupNames)
% Custom SPM12 first-level analysis regression job
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
    
    % -------------------------------------------------------------------------------------------------------------------------------
    %   SPM Settings
    % ----------------
    matlabbatch{1}.spm.stats.factorial_design.dir = {Info.paths.secondla2sTtestSave.fullPath};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans1 = conFilesGrouped{1};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.scans2 = conFilesGrouped{2};
    matlabbatch{1}.spm.stats.factorial_design.des.t2.dept = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.variance = 1;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.gmsca = 0;
    matlabbatch{1}.spm.stats.factorial_design.des.t2.ancova = 0;
    matlabbatch{1}.spm.stats.factorial_design.cov = struct('c', {}, 'cname', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.multi_cov = struct('files', {}, 'iCFI', {}, 'iCC', {});
    matlabbatch{1}.spm.stats.factorial_design.masking.tm.tm_none = 1;
    matlabbatch{1}.spm.stats.factorial_design.masking.im = 0;
    matlabbatch{1}.spm.stats.factorial_design.masking.em = {''};
    matlabbatch{1}.spm.stats.factorial_design.globalc.g_omit = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.gmsca.gmsca_no = 1;
    matlabbatch{1}.spm.stats.factorial_design.globalm.glonorm = 1;

    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep;
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tname = 'Select SPM.mat';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec = {};
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).sname = 'Factorial design specification: SPM.mat File';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).src_output = substruct('.','spmmat');
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;

    matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep;
    matlabbatch{3}.spm.stats.con.spmmat(1).tname = 'Select SPM.mat';
    matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec = {};
    matlabbatch{3}.spm.stats.con.spmmat(1).sname = 'Model estimation: SPM.mat File';
    matlabbatch{3}.spm.stats.con.spmmat(1).src_exbranch = substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{3}.spm.stats.con.spmmat(1).src_output = substruct('.','spmmat');
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.name = [groupNames{1}, ' > ', groupNames{2}];
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.convec = [1 -1];
    matlabbatch{3}.spm.stats.con.consess{1}.tcon.sessrep = 'none';
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.name = [groupNames{1}, ' < ', groupNames{2}];
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.convec = [-1 1];
    matlabbatch{3}.spm.stats.con.consess{2}.tcon.sessrep = 'none';
    matlabbatch{3}.spm.stats.con.delete = 0;
end

