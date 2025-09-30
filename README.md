# nextstrain.org/nipah

This repository contains two workflows for the analysis of Nipah virus data:

- [`ingest/`](./ingest) - Download data from GenBank, clean and curate it, and upload a pair of sequence and metadata files to S3
- [`phylogenetic/`](./phylogenetic) - Filter sequences, align, construct phylogeny and export for visualization.

Each folder contains a README.md with more information.

## Installation

Follow the [standard installation instructions](https://docs.nextstrain.org/en/latest/install.html) for Nextstrain's suite of software tools.

After you've installed the Nextstrain CLI, you can set up nipah with

```bash
nextstrain setup nipah
```

## Quickstart

Run the default phylogenetic workflow via:
```
mkdir nipah-analysis
nextstrain run nipah phylogenetic nipah-analysis
nextstrain view nipah-analysis
```

## Documentation

- [Running a pathogen workflow](https://docs.nextstrain.org/en/latest/tutorials/running-a-workflow.html)