.PHONY: init data report docs clean clobber prune
.DELETE_ON_ERROR:

# data sources
ORGANISATION_CSV=var/organisation.csv
LAD_BOUNDARIES_GEOJSON=var/lad-boundaries.geojson
AddressBase_ZIP=cache/AB76GB_CSV.zip
AddressBase_HEADERS_CSV=cache/addressbase-premium-header-files.zip
AddressBase_CUSTODIANS_ZIP=cache/addressbase-local-custodian-codes.zip
CODEPO_ZIP=cache/codepo_gb.zip
ONSPD_ZIP=cache/ONSPD_MAY_2020_UK.zip
ONSUD_ZIP=cache/ONSUD_MAY_2020.zip
NSPL_ZIP=cache/NSPL_MAY_2020_UK.zip

DOWNLOADS=\
	$(ORGANISATION_CSV)\
	$(AddressBase_ZIP)\
	$(AddressBase_HEADERS_CSV)\
	$(AddressBase_CUSTODIANS_ZIP)\
	$(ONSPD_ZIP)\
	$(ONSUD_ZIP)\
	$(NSPL_ZIP)\
	$(CODEPO_ZIP)

AddressBase_DATA=\
	var/AddressBase/BLPU.csv\
	var/AddressBase/CLASSIFICATION.csv\
	var/AddressBase/DELIVERYPOINTADDRESS.csv\
	var/AddressBase/HEADER.csv\
	var/AddressBase/LPI.csv\
	var/AddressBase/METADATA.csv\
	var/AddressBase/ORGANISATION.csv\
	var/AddressBase/STREET.csv\
	var/AddressBase/STREETDESCRIPTOR.csv\
	var/AddressBase/SUCCESSOR.csv\
	var/AddressBase/TRAILER.csv\
	var/AddressBase/XREF.csv

# published data
DATA=\
	var/README.md\
	data/totals.json

# working data
# -- too big, or proprietary to publish
VAR=\
	$(AddressBase_DATA)\
	var/organisation.csv\
	var/osopenuprn.csv\
	var/codepo.csv\
	var/nspl.csv\
	var/onspd.csv\
	var/onsud.csv\
	var/postcode.csv\
	var/postcode-uprn.csv\
	var/custodian-lad-count.csv\
	var/postcode-uprn-count.csv\
	var/postcode-lad-uprn-count.csv\
	var/postcode-lad-count.csv

all:	docs data

#
#  published pages
#
docs:	docs/index.html

docs/index.html:	bin/render.py templates/guidance.html content/guidance.md
	@mkdir -p docs/
	python3 bin/render.py

data:	addresses.db

addresses.db:	var/organisation.csv var/postcode.csv var/uprn.csv

# postcode table:
# postcode,codepo,onspd,nspl
var/postcode.csv:	var/nspl.csv var/onspd.csv var/codepo.csv bin/postcode.py
	python3 bin/postcode.py | bin/csvsort.sh -t, -k1.1 -k2.2> $@

# uprn table:
# uprn,postcode,addressbase-custodian,onsud
var/uprn.csv:	var/blpu.csv var/onsud.csv
	join --header -t, -1 1 -2 1 var/blpu.csv var/onsud.csv > $@

# cleaned up AddressBase BLPU table:
# uprn,postcode,addressbase-custodian
var/blpu.csv:	var/AddressBase/BLPU.csv bin/uprn.sh
	bin/uprn.sh < var/AddressBase/BLPU.csv > $@

# unpack AddressBase into a file for each record type
$(AddressBase_DATA):	 bin/unpack-addressbase.py $(AddressBase_ZIP) $(AddressBase_HEADERS_CSV)
	@mkdir -p var/AddressBase/
	python3 bin/unpack-addressbase.py $(AddressBase_HEADERS_CSV) $(AddressBase_ZIP)

var/nspl.csv:	$(NSPL_ZIP)
	@mkdir -p var/
	unzip -p $(NSPL_ZIP) 'Data/*.csv' | csvcut -c pcds,laua | sed -e '1{s/pcds,laua/postcode,nspl/}' -e '/^pcds,/d' > $@

var/onspd.csv:	$(ONSPD_ZIP)
	@mkdir -p var/
	unzip -p $(ONSPD_ZIP) 'Data/*.csv' | csvcut -c pcds,oslaua | sed -e '1{s/pcds,oslaua/postcode,onspd/}' -e '/^pcds,/d' > $@

var/onsud.csv:	$(ONSUD_ZIP)
	@mkdir -p var/
	unzip -p $(ONSUD_ZIP) 'Data/*.csv' | csvcut -c uprn,lad19cd | sed -e '1{s/uprn,lad19cd/uprn,onsud/}' -e '1!{/^uprn,/d;}' | bin/csvsort.sh -t, -k1,1 -k2,2 > $@

var/codepo.csv:	$(CODEPO_ZIP)
	@mkdir -p var/
	unzip -p $(CODEPO_ZIP) 'Data/CSV/*.csv' | csvcut -c 1,3,4,9 | sed -e '1i postcode,easting,northing,codepo' > $@

#
#  downloads
#
download: $(DOWNLOADS)

# https://geoportal.statistics.gov.uk/datasets/ons-postcode-directory-may-2020
$(ONSPD_ZIP):
	@mkdir -p ./cache
	curl -qsL 'https://www.arcgis.com/sharing/rest/content/items/fb894c51e72748ec8004cc582bf27e83/data' > $@

# https://geoportal.statistics.gov.uk/datasets/ons-uprn-directory-may-2020
$(ONSUD_ZIP):
	@mkdir -p ./cache
	curl -qsL 'https://www.arcgis.com/sharing/rest/content/items/68879b4d8da545a395a8bc8b95572e7d/data' > $@

# https://geoportal.statistics.gov.uk/datasets/national-statistics-postcode-lookup-may-2020
$(NSPL_ZIP):
	@mkdir -p ./cache
	curl -qsL 'https://www.arcgis.com/sharing/rest/content/items/ab73ec2e38c04599b64b09b3fa1c3333/data' > $@

# https://osdatahub.os.uk/downloads/open/OpenUPRN
$(OPENUPRN_ZIP):
	@mkdir -p ./cache
	curl -qsL 'https://api.os.uk/downloads/v1/products/OpenUPRN/downloads?area=GB&format=CSV&redirect' > $@

# https://www.ordnancesurvey.co.uk/business-government/tools-support/addressbase-premium-support
$(AddressBase_HEADERS_CSV):
	@mkdir -p ./cache
	curl -qsL 'https://www.ordnancesurvey.co.uk/documents/product-support/support/addressbase-premium-header-files.zip' > $@

# https://www.ordnancesurvey.co.uk/business-government/tools-support/addressbase-premium-support
$(AddressBase_CUSTODIANS_ZIP):
	@mkdir -p ./cache
	curl -qsL 'https://www.ordnancesurvey.co.uk/documents/product-support/support/addressbase-local-custodian-codes.zip' > $@

# https://geoportal.statistics.gov.uk/datasets/local-authority-districts-december-2019-boundaries-uk-bfc
$(LAD_BOUNDARIES_GEOJSON):
	@mkdir -p ./cache
	curl -qsL 'https://opendata.arcgis.com/datasets/1d78d47c87df4212b79fe2323aae8e08_0.geojson' > $@

$(CODEPO_ZIP):
	@mkdir -p ./cache
	curl -qsL 'https://api.os.uk/downloads/v1/products/CodePointOpen/downloads?area=GB&format=CSV&redirect' > $@

$(ORGANISATION_CSV):
	@mkdir -p ./var
	curl -qsL 'https://raw.githubusercontent.com/digital-land/organisation-dataset/master/collection/organisation.csv' > $@

#
#  standard targets
#
init:
	pip3 install -r requirements.txt

clobber:
	rm -rf ./doc/ ./data/

clean:	clobber
	rm -rf ./var

prune:	clean
	rm -rf ./cache
