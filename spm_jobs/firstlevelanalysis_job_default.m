function matlabbatch = firstlevelanalysis_job_default(Info, sourceFiles)
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
    matlabbatch{1}.spm.stats.fmri_spec.timing.fmri_t0 = 8;
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
    matlabbatch{1}.spm.stats.fmri_spec.mthresh = 0.4;
    matlabbatch{1}.spm.stats.fmri_spec.mask = {''};
    matlabbatch{1}.spm.stats.fmri_spec.cvi = 'none';
    
    
    % Estimate
    matlabbatch{2}.spm.stats.fmri_est.spmmat = cfg_dep('fMRI model specification: SPM.mat File', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    matlabbatch{2}.spm.stats.fmri_est.write_residuals = 0;
    matlabbatch{2}.spm.stats.fmri_est.method.Classical = 1;
    
    
    % Contrasts
    matlabbatch{3}.spm.stats.con.spmmat = cfg_dep('Model estimation: SPM.mat File', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','spmmat'));
    for i = 1:length(logData{Info.Settings.startSession}.contrasts)
        
        weight = logData{Info.Settings.startSession}.contrasts{i}.weights;
        if isfield(logData{Info.Settings.startSession}.contrasts{i}, 'type')
            if strcmp(logData{Info.Settings.startSession}.contrasts{i}.type, "F")
                weight_ = zeros(length(fieldnames(weight)), length(weight.x1));
                for w = 1:size(weight_, 1)
                    weight_(w, :) = weight.(['x', num2str(w)]);
                end
                matlabbatch{3}.spm.stats.con.consess{i}.fcon.name = logData{Info.Settings.startSession}.contrasts{i}.name;
                matlabbatch{3}.spm.stats.con.consess{i}.fcon.weights = weight_;
                matlabbatch{3}.spm.stats.con.consess{i}.fcon.sessrep = 'repl';
            else
                matlabbatch{3}.spm.stats.con.consess{i}.tcon.name = logData{Info.Settings.startSession}.contrasts{i}.name;
                matlabbatch{3}.spm.stats.con.consess{i}.tcon.weights = weight;
                matlabbatch{3}.spm.stats.con.consess{i}.tcon.sessrep = 'replsc';
            end
        else
            matlabbatch{3}.spm.stats.con.consess{i}.tcon.name = logData{Info.Settings.startSession}.contrasts{i}.name;
            matlabbatch{3}.spm.stats.con.consess{i}.tcon.weights = weight;
            matlabbatch{3}.spm.stats.con.consess{i}.tcon.sessrep = 'replsc';
        end
    end
    matlabbatch{3}.spm.stats.con.delete = 0;
end
