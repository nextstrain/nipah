"""
This part of the workflow constructs the phylogenetic tree.

REQUIRED INPUTS:

    metadata            = data/metadata.tsv
    prepared_sequences  = results/prepared_sequences.fasta

OUTPUTS:

    tree            = results/tree.nwk
    branch_lengths  = results/branch_lengths.json

This part of the workflow usually includes the following steps:

    - augur tree
    - augur refine

See Augur's usage docs for these commands for more details.
"""

rule tree:
    input:
        alignment="builds/{build}/aligned.fasta",
    output:
        tree="builds/{build}/tree_raw.nwk",
    params:
        args=config["tree"]["args"],
    shell:
        """
        augur tree \
            --alignment {input.alignment} \
            --tree-builder-args {params.args} \
            --output {output.tree}
        """


rule refine:
    input:
        tree="builds/{build}/tree_raw.nwk",
        alignment="builds/{build}/masked.fasta",
        metadata="builds/{build}/metadata.tsv",
    output:
        tree="builds/{build}/tree.nwk",
        node_data="builds/{build}/branch_lengths.json",
    params:
        metadata_id_columns=config["strain_id_field"],
        coalescent=config["refine"]["coalescent"],
        date_inference=config["refine"]["date_inference"],
        clock_filter_iqd=config["refine"]["clock_filter_iqd"],
        clock_rate =config["refine"]["clock_rate"],
    shell:
        """
        augur refine \
            --tree {input.tree} \
            --alignment {input.alignment} \
            --metadata {input.metadata} \
            --metadata-id-columns {params.metadata_id_columns} \
            --output-tree {output.tree} \
            --timetree \
            --precision 3 \
            --keep-polytomies \
            --output-node-data {output.node_data} \
            --coalescent {params.coalescent} \
            --date-inference {params.date_inference} \
            --date-confidence \
            --clock-filter-iqd {params.clock_filter_iqd} \
            --clock-rate {params.clock_rate}
        """
