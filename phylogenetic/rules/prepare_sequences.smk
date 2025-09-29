"""
This part of the workflow prepares sequences for constructing the phylogenetic tree.

REQUIRED INPUTS:

    metadata    = results/metadata.tsv
    sequences   = results/sequences.fasta
    reference   = defaults/reference.fasta

OUTPUTS:

    prepared_sequences = results/prepared_sequences.fasta

This part of the workflow usually includes the following steps:

    - augur index
    - augur filter
    - augur align
    - augur mask

See Augur's usage docs for these commands for more details.
"""

rule index:
    input:
        "results/sequences.fasta",
    output:
        "results/sequences.index",
    shell:
        r"""
        augur index \
            --sequences {input:q} \
            --output {output:q}
        """


rule filter:
    input:
        sequences="results/sequences.fasta",
        metadata="results/metadata.tsv",
        exclude=resolve_config_path(config["filter"]["exclude"]),
        index="results/sequences.index",
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
        reference=resolve_config_path(config["nextclade"]["reference_fasta"]),
        genemap=resolve_config_path(config["nextclade"]["genemap"]),
    output:
        alignment="results/{build}/premask.fasta",
    shell:
        r"""
        nextclade3 run \
            --input-ref {input.reference:q} \
            --input-annotation {input.genemap:q} \
            --output-fasta {output.alignment:q} \
            -- \
            {input.fasta:q}
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
        python3 {workflow.basedir}/scripts/mask-alignment.py \
            --alignment {input.alignment:q} \
            --mask-from-beginning {params.mask_from_beginning} \
            --mask-from-end {params.mask_from_end} \
            {params.mask_flags} \
            --output {output.alignment:q}
        """


rule nextclade_after_mask:
    input:
        fasta="results/{build}/masked.fasta",
        reference=resolve_config_path(config["nextclade"]["reference_fasta"]),
        genemap=resolve_config_path(config["nextclade"]["genemap"]),
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
