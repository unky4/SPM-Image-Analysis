function matlabbatch = preprocessing_spm8_job(Info, sourceFiles)
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
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1) = cfg_dep;
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1).tname = 'Source Image';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1).tgt_spec{1}(1).name = 'filter';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1).tgt_spec{1}(1).value = 'image';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1).tgt_spec{1}(2).name = 'strtype';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1).tgt_spec{1}(2).value = 'e';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1).sname = 'Realign: Estimate & Reslice: Mean Image';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.source(1).src_output = substruct('.','rmean');
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.wtsrc = '';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1) = cfg_dep;
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1).tname = 'Images to Write';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1).tgt_spec{1}(1).name = 'filter';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1).tgt_spec{1}(1).value = 'image';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1).tgt_spec{1}(2).name = 'strtype';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1).tgt_spec{1}(2).value = 'e';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1).sname = 'Realign: Estimate & Reslice: Resliced Images (Sess 1)';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(1).src_output = substruct('.','sess', '()',{1}, '.','rfiles');
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2) = cfg_dep;
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2).tname = 'Images to Write';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2).tgt_spec{1}(1).name = 'filter';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2).tgt_spec{1}(1).value = 'image';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2).tgt_spec{1}(2).name = 'strtype';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2).tgt_spec{1}(2).value = 'e';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2).sname = 'Realign: Estimate & Reslice: Mean Image';
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2).src_exbranch = substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{2}.spm.spatial.normalise.estwrite.subj.resample(2).src_output = substruct('.','rmean');
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.template = {fullfile(Info.paths.SPM.fullPath, 'templates', 'EPI.nii,1')};
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.weight = '';
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.smosrc = 8;
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.smoref = 0;
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.regtype = 'mni';
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.cutoff = 25;
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.nits = 16;
    matlabbatch{2}.spm.spatial.normalise.estwrite.eoptions.reg = 1;
    matlabbatch{2}.spm.spatial.normalise.estwrite.roptions.preserve = 0;
    matlabbatch{2}.spm.spatial.normalise.estwrite.roptions.bb = [-78 -112 -50
                                                                 78 76 85];
    matlabbatch{2}.spm.spatial.normalise.estwrite.roptions.vox = [2 2 2];
    matlabbatch{2}.spm.spatial.normalise.estwrite.roptions.interp = 1;
    matlabbatch{2}.spm.spatial.normalise.estwrite.roptions.wrap = [0 0 0];
    matlabbatch{2}.spm.spatial.normalise.estwrite.roptions.prefix = 'w';

    
    
    % Smooth
    matlabbatch{3}.spm.spatial.smooth.data(1) = cfg_dep;
    matlabbatch{3}.spm.spatial.smooth.data(1).tname = 'Images to Smooth';
    matlabbatch{3}.spm.spatial.smooth.data(1).tgt_spec{1}(1).name = 'filter';
    matlabbatch{3}.spm.spatial.smooth.data(1).tgt_spec{1}(1).value = 'image';
    matlabbatch{3}.spm.spatial.smooth.data(1).tgt_spec{1}(2).name = 'strtype';
    matlabbatch{3}.spm.spatial.smooth.data(1).tgt_spec{1}(2).value = 'e';
    matlabbatch{3}.spm.spatial.smooth.data(1).sname = 'Normalise: Estimate & Write: Normalised Images (Subj 1)';
    matlabbatch{3}.spm.spatial.smooth.data(1).src_exbranch = substruct('.','val', '{}',{2}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1});
    matlabbatch{3}.spm.spatial.smooth.data(1).src_output = substruct('()',{1}, '.','files');
    matlabbatch{3}.spm.spatial.smooth.fwhm = [8 8 8];
    matlabbatch{3}.spm.spatial.smooth.dtype = 0;
    matlabbatch{3}.spm.spatial.smooth.im = 0;
    matlabbatch{3}.spm.spatial.smooth.prefix = 's';
end

