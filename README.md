# SPM Image Analysis

A MATLAB toolbox for Presentation-log conversion, SPM preprocessing, first-level modelling, and second-level image analysis.

The toolbox is organised around small pipeline entry points and commented YAML settings files. Imaging inputs are expected to be arranged in BIDS format, which keeps subject and run naming consistent across projects while avoiding project-specific filename settings.

## Repository layout

```text
SPM_Image_Analysis/
├── configs/                    # Commented YAML settings examples
├── functions/                  # Utility functions, including BIDS discovery
├── log_file_readers/           # Presentation/log-reader helpers
├── pipelines/                  # User-facing pipeline entry points
├── spm_jobs/                   # SPM batch-construction functions
├── firstlevelanalysis.m        # First-level SPM workflow
├── preprocessing.m             # Preprocessing workflow
├── secondlevelanalysis.m       # Second-level SPM workflow
├── logs2stan.m                 # User-friendly wrapper for log conversion
├── merge_behavior_tables.m     # User-friendly wrapper for table merging
└── startup_spm_image_analysis.m
```

## BIDS input structure

For a task split into two scanner acquisitions, use BIDS runs:

```text
BIDS_ROOT/
├── dataset_description.json
├── participants.tsv
├── sub-001/
│   └── func/
│       ├── sub-001_task-painstorm_run-01_bold.nii
│       └── sub-001_task-painstorm_run-02_bold.nii
└── sub-002/
    └── func/
        ├── sub-002_task-painstorm_run-01_bold.nii
        └── sub-002_task-painstorm_run-02_bold.nii
```

The settings file asks for the BIDS root, file suffix, and run numbers. Prefixes such as `sub-`, `task-`, and `run-` are handled by the code. The `task` label is optional and should only be added if the dataset contains multiple matching task fMRI files per subject/run.


Presentation logs can also be stored under the subject folder:

```text
BIDS_ROOT/
└── sub-001/
    └── log/
        ├── sub-001_run1.mat
        └── sub-001_run2.mat
```

The log runs are matched to the same run numbers used for the fMRI data.

## Setup

Open MATLAB in the repository root and run:

```matlab
startup_spm_image_analysis
```

This adds the repository, pipeline folder, utility functions, log readers, and SPM job functions to the MATLAB path.

## Run preprocessing

Edit `configs/settings_preprocessing.yaml`, then run:

```matlab
run_preprocessing_pipeline('configs/settings_preprocessing.yaml')
```

For cluster or multi-node use:

```matlab
run_preprocessing_pipeline('configs/settings_preprocessing.yaml', ...
    'nofNodesToUse', 4, ...
    'nodeID', 2)
```

## Run one first- and second-level analysis

Edit `configs/settings_analysis_onsets_outcome_outcome.yaml`, then run:

```matlab
run_analysis_pipeline('configs/settings_analysis_onsets_outcome_outcome.yaml')
```

The `analysis_pipeline` section controls the analysis name, whether the first-level model should run, the first-level SPM job function, group-comparison CSV files, and regression-parameter CSV files.

## Run several analyses

Edit `configs/batch_analysis.yaml`, then run:

```matlab
run_batch_analysis_pipeline('configs/batch_analysis.yaml')
```

Each analysis listed in the batch file is passed through the same single-analysis pipeline, which keeps large analysis batches readable and reproducible.

## Convert behavioural logs

Edit `configs/settings_log_pipeline.yaml`, then run:

```matlab
run_log_pipeline('configs/settings_log_pipeline.yaml')
```

The public wrapper is named `logs2stan.m`. The original `log2stan.m` function is retained so older scripts continue to work.

## YAML settings

YAML is recommended because it allows comments. The loader accepts `.yaml`, `.yml`, and `.json` files. YAML loading is attempted using `ReadYaml`, then Python/PyYAML, then a small built-in parser that supports the structure used by the example configs.

## Main settings

```yaml
resmem: true
spmPath: "/path/to/spm12"
saveRoot: "/path/to/analysis_output"
nofSlicesToDiscard: 4

bids:
  enabled: true
  root: "/path/to/BIDS"
  suffix: "bold"
  runs: [1, 2]
  subject_labels: []

# Optional, only needed to disambiguate multiple matching func files:
# task: "painstorm"
```

For the log pipeline, use:

```yaml
bids:
  enabled: true
  root: "/path/to/BIDS"
  runs: [1, 2]

log_pipeline:
  output_dir: "/path/to/behaviour_tables"
  file_name: "data_combined_image_analysis"
  logs:
    source: "bids"
    folder: "log"
```

Use `runs` for repeated task acquisitions. In this project, the old “session” concept maps to BIDS runs.

## Notes

- BIDS filenames should use the standard entity order, for example `sub-001_task-painstorm_run-01_bold.nii`. The pipeline can infer the task label when that is the only matching task file for a subject/run.
- The toolbox can read `.nii` and `.nii.gz` inputs. Compressed files are copied and unzipped in the preprocessing output folder before SPM runs.
- Keep project-specific SPM batch details in `spm_jobs/`.
- Keep user-facing pipeline scripts in `pipelines/`.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
