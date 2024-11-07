"""
This part of the workflow collects the phylogenetic tree and annotations to
export a Nextstrain dataset.

REQUIRED INPUTS:

    metadata        = data/metadata.tsv
    tree            = results/tree.nwk
    branch_lengths  = results/branch_lengths.json
    node_data       = results/*.json

OUTPUTS:

    auspice_json = auspice/${build_name}.json

    There are optional sidecar JSON files that can be exported as part of the dataset.
    See Nextstrain's data format docs for more details on sidecar files:
    https://docs.nextstrain.org/page/reference/data-formats.html

This part of the workflow usually includes the following steps:

    - augur export v2
    - augur frequencies

See Augur's usage docs for these commands for more details.
"""

rule download_lat_longs:
    output:
        "builds/lat_longs.tsv",
    params:
        url="https://raw.githubusercontent.com/nextstrain/ncov/master/defaults/lat_longs.tsv",
    shell:
        """
        curl {params.url} | \
        sed "s/North Rhine Westphalia/North Rhine-Westphalia/g" | \
        sed "s/Baden-Wuerttemberg/Baden-Wurttemberg/g" \
        > {output}
        """


rule export:
    input:
        tree="builds/{build}/tree.nwk",
        node_data="builds/{build}/branch_lengths.json",
        clades="builds/{build}/clades.json",
        ancestral="builds/{build}/muts.json",
        description=config["export"]["description"],
        auspice_config=config["export"]["auspice_config"],
        lat_longs=rules.download_lat_longs.output,
        metadata="builds/{build}/metadata.tsv",
    output:
        auspice_json="auspice/nipah_{build}.json",
    shell:
        """
        augur export v2 \
            --tree {input.tree} \
            --node-data {input.node_data} {input.ancestral} {input.clades} \
            --include-root-sequence-inline \
            --description {input.description} \
            --auspice-config {input.auspice_config} \
            --lat-longs {input.lat_longs} \
            --output {output.auspice_json} \
            --metadata-id-columns accession \
            --metadata {input.metadata}
        """
