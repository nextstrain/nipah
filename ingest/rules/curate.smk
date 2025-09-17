"""
This part of the workflow handles the curation of metadata for sequences
from NCBI and outputs the clean data as two separate files:

    - results/subset_metadata.tsv
    - results/sequences.fasta
"""


# The following two rules can be ignored if you choose not to use the
# generalized geolocation rules that are shared across pathogens.
# The Nextstrain team will try to maintain a generalized set of geolocation
# rules that can then be overridden by local geolocation rules per pathogen repo.
rule fetch_general_geolocation_rules:
    output:
        general_geolocation_rules="data/general-geolocation-rules.tsv",
    params:
        geolocation_rules_url=config["curate"]["geolocation_rules_url"],
    shell:
        r"""
        curl {params.geolocation_rules_url:q} > {output.general_geolocation_rules:q}
        """


rule concat_geolocation_rules:
    input:
        general_geolocation_rules="data/general-geolocation-rules.tsv",
        local_geolocation_rules=resolve_config_path(config["curate"]["local_geolocation_rules"]),
    output:
        all_geolocation_rules="data/all-geolocation-rules.tsv",
    shell:
        r"""
        cat {input.general_geolocation_rules:q} {input.local_geolocation_rules:q} >> {output.all_geolocation_rules:q}
        """


def format_field_map(field_map: dict[str, str]) -> str:
    """
    Format dict to `"key1"="value1" "key2"="value2"...` for use in shell commands.
    """
    return " ".join([f'"{key}"="{value}"' for key, value in field_map.items()])


# This curate pipeline is based on existing pipelines for pathogen repos using NCBI data.
# You may want to add and/or remove steps from the pipeline for custom metadata
# curation for your pathogen. Note that the curate pipeline is streaming NDJSON
# records between scripts, so any custom scripts added to the pipeline should expect
# the input as NDJSON records from stdin and output NDJSON records to stdout.
# The final step of the pipeline should convert the NDJSON records to two
# separate files: a metadata TSV and a sequences FASTA.
rule curate:
    input:
        sequences_ndjson="data/ncbi.ndjson",
        # Change the geolocation_rules input path if you are removing the above two rules
        all_geolocation_rules="data/all-geolocation-rules.tsv",
        annotations=resolve_config_path(config["curate"]["annotations"]),
    output:
        metadata="data/all_metadata.tsv",
        sequences="results/sequences.fasta",
    log:
        "logs/curate.txt",
    benchmark:
        "benchmarks/curate.txt"
    params:
        field_map=format_field_map(config["curate"]["field_map"]),
        date_fields=config["curate"]["date_fields"],
        expected_date_formats=config["curate"]["expected_date_formats"],
        genbank_location_field=config["curate"]["genbank_location_field"],
        articles=config["curate"]["titlecase"]["articles"],
        abbreviations=config["curate"]["titlecase"]["abbreviations"],
        titlecase_fields=config["curate"]["titlecase"]["fields"],
        authors_field=config["curate"]["authors_field"],
        authors_default_value=config["curate"]["authors_default_value"],
        abbr_authors_field=config["curate"]["abbr_authors_field"],
        annotations_id=config["curate"]["annotations_id"],
        id_field=config["curate"]["output_id_field"],
        sequence_field=config["curate"]["output_sequence_field"],
    shell:
        r"""
        (cat {input.sequences_ndjson:q} \
            | augur curate rename \
                --field-map {params.field_map} \
            | augur curate normalize-strings \
            | augur curate format-dates \
                --date-fields {params.date_fields} \
                --expected-date-formats {params.expected_date_formats} \
            | augur curate parse-genbank-location \
                --location-field {params.genbank_location_field} \
            | augur curate titlecase \
                --titlecase-fields {params.titlecase_fields} \
                --articles {params.articles} \
                --abbreviations {params.abbreviations} \
            | augur curate abbreviate-authors \
                --authors-field {params.authors_field} \
                --default-value {params.authors_default_value} \
                --abbr-authors-field {params.abbr_authors_field} \
            | augur curate apply-geolocation-rules \
                --geolocation-rules {input.all_geolocation_rules:q} \
            | augur curate apply-record-annotations \
                --annotations {input.annotations:q} \
                --id-field {params.annotations_id} \
            | augur curate passthru \
                --output-metadata {output.metadata:q} \
                --output-fasta {output.sequences:q} \
                --output-id-field {params.id_field} \
                --output-seq-field {params.sequence_field} ) 2>> {log:q}
        """

rule add_metadata_columns:
    """Add columns to metadata
    Notable columns:
    - [NEW] url: URL linking to the NCBI GenBank record ('https://www.ncbi.nlm.nih.gov/nuccore/*').
    """
    input:
        metadata = "data/all_metadata.tsv"
    output:
        metadata = temp("data/all_metadata_added.tsv")
    params:
        accession=config['curate']['genbank_accession']
    shell:
        r"""
        csvtk mutate2 -t \
          -n url \
          -e '"https://www.ncbi.nlm.nih.gov/nuccore/" + ${params.accession}' \
          {input.metadata:q} \
        > {output.metadata:q}
        """

rule subset_metadata:
    input:
        metadata="data/all_metadata_added.tsv",
    output:
        subset_metadata="results/metadata.tsv",
    params:
        metadata_fields=",".join(config["curate"]["metadata_columns"]),
    shell:
        r"""
        tsv-select -H -f {params.metadata_fields} \
            {input.metadata} > {output.subset_metadata:q}
        """
