#!/bin/bash

# function for creating config files
make_config () {
    NAME=$1
    TITLE=$2
    PROFILE=$3
    DESCRIPTION=$4

    URL="\${projectDir}/assets/datasets/${NAME}"

    NAME=${NAME%.csv}

    cat template.config | \
        sed "s/TITLE/${TITLE}/g" | \
        sed "s/PROFILE/${PROFILE}/g" | \
        sed "s/DESCRIPTION/${DESCRIPTION}/g" | \
        sed "s/URL/${URL//\//\\/}/g" \
        > ../../conf/${NAME}.config
    
    echo "    ${NAME,,} { includeConfig '${NAME}.config' }" >> ../../conf/db_profiles.config
}

#-----START-----#
# remove current files
rm *_db.csv
rm ../../conf/*_db.config
# start new profile config
echo "profiles {" > ../../conf/db_profiles.config
# start new database summary
echo ""
# download HTML for the PopPUNK database repo page
wget https://www.bacpop.org/poppunk/ -O pp.html

#----- ALL TAXA -----#
# samplesheet header
echo "taxa,pp_db" > all_dbs.csv
# extract all taxa from HTML table
cat pp.html | \
    sed 's/<td><i>/\n/g' | \
    grep '</i>' | \
    sed 's/<\/i><\/td>/\t/g' | \
    sed -E 's/[</]+i>//g' | \
    tr ' ' '_' | \
    sed -E 's/htt[ps]+:\/\/ftp/\t&/g' | \
    cut -f 1,3 | \
    sed 's/>Download.*//g' | \
    awk -v OFS=',' '$2 != "" {print $1,$2}' | \
    grep 'refs' \
    >> all_dbs.csv

# create config file
make_config \
    all_dbs.csv \
    "Nextflow config file for preparing all species\n    database available on the PopPUNK repository" \
    "All Databases" \
    "All PopPUNK databases available on the developer repository"


#---- INDIVIDUAL TAXON -----#
for LINE in $(cat all_dbs.csv | tail -n +2)
do
    # get taxon name
    TAXON=$(echo $LINE | cut -f 1 -d ',')
    # create samplesheet
    echo "taxa,pp_db" > ${TAXON}_db.csv
    echo $LINE >> ${TAXON}_db.csv
    # create config file
    make_config \
        ${TAXON}_db.csv \
         "Nextflow config file for preparing the\n    ${TAXON//_/ } PopPUNK database" \
        "${TAXON} Databases" \
        "${TAXON} PopPUNK databases"
done

#----- TEST DATABASE -----#
cp Acinetobacter_baumannii_db.csv test_db.csv
# create config file
make_config \
    test_db.csv \
    "Nextflow config file for running minimal \n    test of the "PREPARE_DB" workflow." \
    "PREPARE_DB Test" \
    "Runs minimal test of the "PREPARE_DB" workflow."

#----- EXAMPLE DATABASE -----#
cp Acinetobacter_baumannii_db.csv example_db.csv
cat Klebsiella_pneumoniae_db.csv | tail -n +2 >> example_db.csv
# create config file
make_config \
    example_db.csv \
    "Nextflow config file for downloading the\n    database files for the wiki example" \
    "Wiki Example: Database" \
    "Nextflow config file for downloading the database files for the wiki example"

#-----END-----# 
# close db_profiles config
echo "}" >> ../../conf/db_profiles.config
# create list of databases
cat ../../conf/db_profiles.config | grep includeConfig | cut -f 5 -d ' ' | grep -Ev 'test_db|example_db' > ../../docs/db_profiles.md
# clean up
rm pp.html