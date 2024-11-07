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
        sequences="results/{build}/sequences.fasta",
        metadata="results/{build}/metadata.tsv",
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


rule nextclade_before_mask:
    input:
        fasta="results/{build}/sequences.fasta",
        reference=config["nextclade"]["reference_fasta"],
        genemap=config["nextclade"]["genemap"],
    output:
        alignment="results/{build}/premask.fasta",
    shell:
        """
        nextclade3 run \
            --input-ref {input.reference} \
            --input-annotation {input.genemap} \
            --output-fasta {output.alignment} \
            -- {input.fasta}
        """


rule mask:
    input:
        alignment="results/{build}/premask.fasta",
    output:
        alignment="results/{build}/masked.fasta",
    shell:
        """
        python3 scripts/mask-alignment.py \
            --alignment {input.alignment} \
            --mask-from-beginning 100 \
            --mask-from-end 100 \
            --mask-terminal-gaps \
            --output {output.alignment}
        """


rule nextclade_after_mask:
    input:
        fasta="results/{build}/masked.fasta",
        reference=config["nextclade"]["reference_fasta"],
        genemap=config["nextclade"]["genemap"],
    output:
        alignment="results/{build}/aligned.fasta",
    params:
        template_string=lambda w: f"results/{w.build}/translations/gene.{{cds}}.fasta",
        genes=",".join(genes),
    shell:
        """
        nextclade3 run \
            --input-ref {input.reference} \
            --input-annotation {input.genemap} \
            --cds-selection {params.genes} \
            --output-translations {params.template_string} \
            --output-fasta {output.alignment} \
            -- {input.fasta}
        """
