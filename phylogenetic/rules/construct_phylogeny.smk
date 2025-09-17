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
        coalescent=config["refine"]["coalescent"],
        date_inference=config["refine"]["date_inference"],
        clock_filter_iqd=config["refine"]["clock_filter_iqd"],
        clock_rate =config["refine"]["clock_rate"],
    shell:
        r"""
        augur refine \
            --tree {input.tree:q} \
            --alignment {input.alignment:q} \
            --metadata {input.metadata:q} \
            --metadata-id-columns {params.metadata_id_columns:q} \
            --output-tree {output.tree:q} \
            --timetree \
            --precision 3 \
            --keep-polytomies \
            --output-node-data {output.node_data:q} \
            --coalescent {params.coalescent:q} \
            --date-inference {params.date_inference:q} \
            --date-confidence \
            --clock-filter-iqd {params.clock_filter_iqd:q} \
            --clock-rate {params.clock_rate:q}
        """
