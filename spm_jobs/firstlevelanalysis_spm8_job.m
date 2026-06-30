function matlabbatch = firstlevelanalysis_spm8_job(Info, sourceFiles)
% Custom SPM12 first-level analysis job
%
%   Inputs:
%       - Info: The Info structure
%       - sourceFiles: Cell containing the path of an fMRI file with slices
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

    % Load the loginfo files, need some info from them
    logData = cell(Info.Settings.endSession, 1);
    for ses = Info.Settings.startSession:Info.Settings.endSession
        logData{ses} = load(Info.paths.loginfo(ses).fullPath);
    end

    
    % -------------------------------------------------------------------------------------------------------------------------------
    %   SPM Settings
    % ----------------
    %   Note: Using SPM dependency in a batch (cfg_dep) is safe in this
    %         case too. If you leave out the first few images from the
    %         initial sourceFiles, then in later stages, when you use
    %         dependency, SPM will be able to handle this.
    % Model specification   
    matlabbatch{1}.spm.stats.fmri_spec.dir = {Info.paths.firstlaSave.fullPath};
    matlabbatch{1}.spm.stats.fmri_spec.timing.units = logData{Info.Settings.startSession}.units;
    matlabbatch{1}.spm.stats.fmri_spec.timing.RT = logData{Info.Settings.startSession}.TR;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t = 16;
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 1; % was 8 by default in spm12
    for ses = Info.Settings.startSession:Info.Settings.endSession
        sesN = ses - Info.Settings.startSession + 1;
        matlabbatch{1}.spm.stats.fmri_spec.sess(sesN).scans = sourceFiles{ses};
        matlabbatch{1}.spm.stats.fmri_spec.sess(sesN).cond = struct('name', {}, 'onset', {}, 'duration', {}, 'tmod', {}, 'pmod', {}, 'orth', {});
        matlabbatch{1}.spm.stats.fmri_spec.sess(sesN).multi = {Info.paths.loginfo(ses).fullPath};
        matlabbatch{1}.spm.stats.fmri_spec.sess(sesN).regress = struct('name', {}, 'val', {});
        matlabbatch{1}.spm.stats.fmri_spec.sess(sesN).multi_reg = {Info.paths.preprocessingFile_rp(ses).fullPath};
        matlabbatch{1}.spm.stats.fmri_spec.sess(sesN).hpf = 128;
    end
    matlabbatch{1}.spm.stats.fmri_spec.fact = struct('name', {}, 'levels', {});
    matlabbatch{1}.spm.stats.fmri_spec.bases.hrf.derivs = [0 0];
    matlabbatch{1}.spm.stats.fmri_spec.volt = 1;
    matlabbatch{1}.spm.stats.fmri_spec.global = 'None';
    %matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.8; % does not exists I guess in spm8
    matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'none'; % was 'AR(1)' by default;
    
    
    % Estimate
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1) = cfg_dep;
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tname = 'Select SPM.mat';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).name = 'filter';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(1).value = 'mat';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).name = 'strtype';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).tgt_spec{1}(2).value = 'e';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).sname = 'fMRI model specification: SPM.mat File';
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{2}.spm.stats.fmri_est.spmmat(1).src_output = substruct('.','spmmat');
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
    
    
    % Contrasts
    matlabbatch{3}.spm.stats.con.spmmat(1) = cfg_dep;
    matlabbatch{3}.spm.stats.con.spmmat(1).tname = 'Select SPM.mat';
    matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec{1}(1).name = 'filter';
    matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec{1}(1).value = 'mat';
    matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec{1}(2).name = 'strtype';
    matlabbatch{3}.spm.stats.con.spmmat(1).tgt_spec{1}(2).value = 'e';
    matlabbatch{3}.spm.stats.con.spmmat(1).sname = 'Model estimation: SPM.mat File';
    matlabbatch{3}.spm.stats.con.spmmat(1).src_exbranch = substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{3}.spm.stats.con.spmmat(1).src_output = substruct('.','spmmat');
    for i = 1:length(logData{Info.Settings.startSession}.contrasts)
        matlabbatch{3}.spm.stats.con.consess{i}.tcon.name = logData{Info.Settings.startSession}.contrasts{i}.name;
        matlabbatch{3}.spm.stats.con.consess{i}.tcon.convec = logData{Info.Settings.startSession}.contrasts{i}.weights;
        matlabbatch{3}.spm.stats.con.consess{i}.tcon.sessrep = 'replsc';
    end
    matlabbatch{3}.spm.stats.con.delete = 0;
    
end
