"""
This part of the workflow constructs the phylogenetic tree.

REQUIRED INPUTS:

    metadata            = results/{build}/metadata.tsv
    prepared_sequences  = results/{build}/sequences.fasta

OUTPUTS:

    tree            = results/{build}/tree.nwk
    branch_lengths  = results/{build}/branch_lengths.json

This part of the workflow usually includes the following steps:

    - augur tree
    - augur refine

See Augur's usage docs for these commands for more details.
"""

rule tree:
    input:
        alignment="results/{build}/aligned.fasta",
    output:
        tree="results/{build}/tree_raw.nwk",
    params:
        args=config["tree"]["args"],
    shell:
        r"""
        augur tree \
            --alignment {input.alignment:q} \
            --tree-builder-args {params.args} \
            --output {output.tree:q}
        """


rule refine:
    input:
        tree="results/{build}/tree_raw.nwk",
        alignment="results/{build}/masked.fasta",
        metadata="results/{build}/metadata.tsv",
    output:
        tree="results/{build}/tree.nwk",
        node_data="results/{build}/branch_lengths.json",
    params:
        metadata_id_columns=config["strain_id_field"],
        refine_flags = config["refine"]["refine_flags"]
    shell:
        r"""
        augur refine \
            --tree {input.tree:q} \
            --alignment {input.alignment:q} \
            --metadata {input.metadata:q} \
            --metadata-id-columns {params.metadata_id_columns:q} \
            --output-tree {output.tree:q} \
            --output-node-data {output.node_data:q} \
            {params.refine_flags}
        """
