# nf-core/pairgenomealign: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Dev

### `Changed`

- [PR #51](https://github.com/nf-core/pairgenomealign/pull/51) Updated the JSON schema to make input validation stricter, thus preventing more errors during the pipeline run.

## [v2.0.0](https://github.com/nf-core/pairgenomealign/releases/tag/2.0.0) "Naga imo" - [February 5th, 2025]

### `Breaking changes`

- The LAST software was updated and it has new defaults for some of its
  parameters. The alignments ran with this pipeline will not be identical to
  the ones from older versions.

### `Added`

- The `alignment/lastdb` directory is not output anymore. It consumed space,
  is not usually needed for downstream analysis, and can be re-computed
  identically if needed.
- The _many-to-one_ alignment file is not output anymore by default, to save
  space. To keep this file, you can run the pipeline in `many-to-many` mode
  with the `--m2m` parameter.
- The `--seed` parameter allows for all the existing values in the `lastdb`
  program.
- Errors caused by absence of alignments at training or plotting steps
  are now ignored.
- New parameter `--export_aln_to` that creates additional files containing
  the alignments in a different format such as Axt, Chain, GFF or SAM.

### `Fixed`

- Incorrect detection of regions with 10 or more `N`s was corrected ([#18](https://github.com/nf-core/pairgenomealign/issues/18)).
- The `--lastal_params` now works as intended instead of being ignored ([#22](https://github.com/nf-core/pairgenomealign/issues/22)).
- The _workflow summary_ is now properly sorted at the end of the MultiQC report ([#32](https://github.com/nf-core/pairgenomealign/issues/32)).
- Conforms to nf-core template version 3.2.0 ([#40](https://github.com/nf-core/pairgenomealign/pull/40)).

### `Parameters`

| Old parameter | New parameter     |
| ------------- | ----------------- |
|               | `--export_aln_to` |

### `Dependencies`

| Dependency | Old version | New version |
| ---------- | ----------- | ----------- |
| `LAST`     | 1542        | 1608        |
| `MultiQC`  | 1.25.1      | 1.27        |

## [v1.1.1](https://github.com/nf-core/pairgenomealign/releases/tag/1.1.1) "Kani nabe" - [December 17th, 2024]

### `Fixed`

- This release brings the pipeline to the standards of Nextflow 24.10.1 and
  nf-core 3.1.0.

## [v1.1.0](https://github.com/nf-core/pairgenomealign/releases/tag/1.1.0) "Nattou maki" - [September 27th, 2024]

### `Added`

- Added a new `softmask` parameter, to optionally keep original softmasking.

### `Parameters`

| Old parameter | New parameter |
| ------------- | ------------- |
|               | `--softmask`  |

## [v1.0.0](https://github.com/nf-core/pairgenomealign/releases/tag/1.0.0) "Sweet potato" - [August 27th, 2024]

Initial release of nf-core/pairgenomealign, created with the [nf-core](https://nf-co.re/) template.
