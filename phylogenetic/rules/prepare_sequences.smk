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
        r"""
        curl -fsSL --compressed {params.sequences_url:q} --output {output.sequences:q}
        curl -fsSL --compressed {params.metadata_url:q} --output {output.metadata:q}
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
        r"""
        zstd -d -c {input.sequences:q} > {output.sequences:q}
        zstd -d -c {input.metadata:q} > {output.metadata:q}
        """


rule index:
    input:
        "data/sequences.fasta",
    output:
        "data/sequences.index",
    shell:
        r"""
        augur index \
            --sequences {input:q} \
            --output {output:q}
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
        r"""
        augur filter \
            --sequences {input.sequences:q} \
            --metadata {input.metadata:q} \
            --metadata-id-columns {params.metadata_id_columns:q} \
            --exclude {input.exclude:q} \
            --sequence-index {input.index:q} \
            --min-length {params.min_length:q} \
            {params.exclude_where} \
            --output-sequences {output.sequences:q} \
            --output-metadata {output.metadata:q}
        """


rule nextclade_before_mask:
    input:
        fasta="results/{build}/sequences.fasta",
        reference=config["nextclade"]["reference_fasta"],
        genemap=config["nextclade"]["genemap"],
    output:
        alignment="results/{build}/premask.fasta",
    shell:
        r"""
        nextclade3 run \
            --input-ref {input.reference:q} \
            --input-annotation {input.genemap:q} \
            --output-fasta {output.alignment:q} \
            -- {input.fasta:q}
        """


rule mask:
    input:
        alignment="results/{build}/premask.fasta",
    output:
        alignment="results/{build}/masked.fasta",
    params:
        mask_from_beginning=config["mask"]["mask_from_beginning"],
        mask_from_end=config["mask"]["mask_from_end"],
        mask_flags=config["mask"]["mask_flags"]
    shell:
        r"""
        python3 scripts/mask-alignment.py \
            --alignment {input.alignment:q} \
            --mask-from-beginning {params.mask_from_beginning} \
            --mask-from-end {params.mask_from_end} \
            {params.mask_flags} \
            --output {output.alignment:q}
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
        genes=",".join(config["genes"]),
    shell:
        r"""
        nextclade3 run \
            --input-ref {input.reference:q} \
            --input-annotation {input.genemap:q} \
            --cds-selection {params.genes} \
            --output-translations {params.template_string} \
            --output-fasta {output.alignment:q} \
            -- {input.fasta:q}
        """
