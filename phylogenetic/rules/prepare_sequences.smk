"""
This part of the workflow prepares sequences for constructing the phylogenetic tree.

REQUIRED INPUTS:

    metadata    = data/metadata.tsv
    sequences   = data/sequences.fasta
    reference   = ../shared/reference.fasta

OUTPUTS:

    prepared_sequences = results/prepared_sequences.fasta

This part of the workflow usually includes the following steps:

    - augur index
    - augur filter
    - augur align
    - augur mask

See Augur's usage docs for these commands for more details.
"""

rule download:
    """Downloading sequences and metadata from data.nextstrain.org"""
    output:
        sequences = "data/sequences.fasta.zst",
        metadata = "data/metadata.tsv.zst"
    params:
        sequences_url = config["sequences_url"],
        metadata_url = config["metadata_url"],
    shell:
        """
        curl -fsSL --compressed {params.sequences_url:q} --output {output.sequences}
        curl -fsSL --compressed {params.metadata_url:q} --output {output.metadata}
        """


rule decompress:
    """Decompressing sequences and metadata"""
    input:
        sequences = "data/sequences.fasta.zst",
        metadata = "data/metadata.tsv.zst"
    output:
        sequences = "data/sequences.fasta",
        metadata = "data/metadata.tsv"
    shell:
        """
        zstd -d -c {input.sequences} > {output.sequences}
        zstd -d -c {input.metadata} > {output.metadata}
        """


rule index:
    input:
        "data/sequences.fasta",
    output:
        "data/sequences.index",
    shell:
        """
        augur index \
            --sequences {input} \
            --output {output}
        """


rule filter:
    input:
        sequences="data/sequences.fasta",
        metadata="data/metadata.tsv",
        exclude=config["filter"]["exclude"],
        index="data/sequences.index",
    output:
        sequences="builds/{build}/sequences.fasta",
        metadata="builds/{build}/metadata.tsv",
    params:
        metadata_id_columns=config["strain_id_field"],
        min_length=config["filter"]["min_length"],
        exclude_where=lambda wildcard: config['filter']['exclude_where'][wildcard.build],
    shell:
        """
        augur filter \
            --sequences {input.sequences} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.metadata_id_columns} \
            --exclude {input.exclude} \
            --sequence-index {input.index} \
            --min-length {params.min_length} \
            {params.exclude_where} \
            --output {output.sequences} \
            --output-metadata {output.metadata}
        """


rule nextalign_before_mask:
    input:
        fasta="builds/{build}/sequences.fasta",
        reference=config["nextalign"]["reference_fasta"],
        genemap=config["nextalign"]["genemap"],
    output:
        alignment="builds/{build}/premask.fasta",
    shell:
        """
        nextalign run \
            --input-ref {input.reference} \
            --input-gene-map {input.genemap} \
            --output-fasta {output.alignment} \
            -- {input.fasta}
        """


rule mask:
    input:
        alignment="builds/{build}/premask.fasta",
    output:
        alignment="builds/{build}/masked.fasta",
    shell:
        """
        python3 scripts/mask-alignment.py \
            --alignment {input.alignment} \
            --mask-from-beginning 100 \
            --mask-from-end 100 \
            --mask-terminal-gaps \
            --output {output.alignment}
        """


rule nextalign_after_mask:
    input:
        fasta="builds/{build}/masked.fasta",
        reference=config["nextalign"]["reference_fasta"],
        genemap=config["nextalign"]["genemap"],
    output:
        alignment="builds/{build}/aligned.fasta",
    params:
        template_string=lambda w: f"builds/{w.build}/translations/gene.{{gene}}.fasta",
        genes=",".join(genes),
    shell:
        """
        nextalign run \
            --input-ref {input.reference} \
            --input-gene-map {input.genemap} \
            --genes {params.genes} \
            --output-translations {params.template_string} \
            --output-fasta {output.alignment} \
            -- {input.fasta}
        """
