function matlabbatch = preprocessing_job(Info, sourceFiles)
% Custom SPM12 preprocessing job
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

    % -------------------------------------------------------------------------------------------------------------------------------
    %   SPM Settings
    % ----------------
    %   Note: Using SPM dependency in a batch (cfg_dep) is safe in this
    %         case too. If you leave out the first few images from the
    %         initial sourceFiles, then in later stages, when you use
    %         dependency, SPM will be able to handle this.
    % Realign
    matlabbatch{1}.spm.spatial.realign.estwrite.data = {sourceFiles};
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.quality = 0.9;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.sep = 4;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.fwhm = 5;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.rtm = 1;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.interp = 2;
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.realign.estwrite.eoptions.weight = '';
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.which = [2 1];
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.interp = 4;
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.mask = 1;
    matlabbatch{1}.spm.spatial.realign.estwrite.roptions.prefix = 'r';
    
    
    % Normalise
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.vol(1) = cfg_dep('Realign: Estimate & Reslice: Mean Image', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','rmean'));
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1) = cfg_dep('Realign: Estimate & Reslice: Resliced Images (Sess 1)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','sess', '()',{1}, '.','rfiles'));
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.biasreg = 0.0001;
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.biasfwhm = 60;
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.tpm = {fullfile(Info.paths.SPM.fullPath, 'tpm', 'TPM.nii')};
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.affreg = 'mni';
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.reg = [0 0.001 0.5 0.05 0.2];
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.fwhm = 0;
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.samp = 3;
    matlabbatch{2}.spm.spatial.normalise.estwrite.woptions.bb = [-78 -112 -70
                                                                 78 76 85];
    matlabbatch{2}.spm.spatial.normalise.estwrite.woptions.vox = [2 2 2];
    matlabbatch{2}.spm.spatial.normalise.estwrite.woptions.interp = 4;
    matlabbatch{2}.spm.spatial.normalise.estwrite.woptions.prefix = 'w';
    
    
    % Smooth
    matlabbatch{3}.spm.spatial.smooth.data(1) = cfg_dep('Normalise: Estimate & Write: Normalised Images (Subj 1)', substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('()',{1}, '.','files'));
    matlabbatch{3}.spm.spatial.smooth.fwhm = [8 8 8];
    matlabbatch{3}.spm.spatial.smooth.dtype = 0;
    matlabbatch{3}.spm.spatial.smooth.im = 0;
    matlabbatch{3}.spm.spatial.smooth.prefix = 's';
end

