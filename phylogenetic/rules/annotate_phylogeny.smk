"""
This part of the workflow creates additonal annotations for the phylogenetic tree.

REQUIRED INPUTS:

    metadata            = results/{build}/metadata.tsv
    prepared_sequences  = results/{build}/sequences.fasta
    tree                = results/{build}/tree.nwk

OUTPUTS:

    node_data = results/{build}/*.json

    There are no required outputs for this part of the workflow as it depends
    on which annotations are created. All outputs are expected to be node data
    JSON files that can be fed into `augur export`.

    See Nextstrain's data format docs for more details on node data JSONs:
    https://docs.nextstrain.org/page/reference/data-formats.html

This part of the workflow usually includes the following steps:

    - augur traits
    - augur ancestral
    - augur translate
    - augur clades

See Augur's usage docs for these commands for more details.

Custom node data files can also be produced by build-specific scripts in addition
to the ones produced by Augur commands.
"""

rule ancestral:
    input:
        tree="results/{build}/tree.nwk",
        alignment="results/{build}/premask.fasta",
        annotation=resolve_config_path(config["ancestral"]["reference_gb"]),
    output:
        node_data="results/{build}/muts.json",
    params:
        inference="joint",
        translations="results/{build}/translations/gene.%GENE.fasta",
        genes=" ".join(config["genes"]),
    shell:
        r"""
        augur ancestral \
            --tree {input.tree:q} \
            --alignment {input.alignment:q} \
            --output-node-data {output.node_data:q} \
            --inference {params.inference:q} \
            --genes {params.genes} \
            --annotation {input.annotation:q} \
            --translations {params.translations:q} \
            --root-sequence {input.annotation:q} \
            2>&1 | tee {log:q}
        """

rule clades:
    input:
        tree="results/{build}/tree.nwk",
        node_data="results/{build}/muts.json",
        clades=resolve_config_path(config["clades"]["clades_defining_mutations"]),
    output:
        clades="results/{build}/clades.json",
    shell:
        r"""
        augur clades \
            --tree {input.tree:q} \
            --mutations {input.node_data:q} \
            --clades {input.clades:q} \
            --output-node-data {output.clades:q}
        """
