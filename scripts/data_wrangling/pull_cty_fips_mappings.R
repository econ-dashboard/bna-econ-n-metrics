################################################################################
# Authors: Rachel Oh, Michael Spencer
# Project: BNA-ECON-N-METRICS
# Script Purpose: Gather and process the county FIPS mappings from the BLS. 
# The script generates a CSV for all available counties, and for each county,
# provides the FIPS code, name of the area, and the file path/URL for the county's
# HTML page.
# Notes: Pulls the 2020 FIPS codes for counties or equivalent entities via a URL. 
# A copy of this data is also stored locally should the URL ever fail to work.
################################################################################

if (!exists("running_pipeline")) source("lib/load_r_libraries.R")

# Start timer
tic("FIPS data scrape")

writeLines("")
writeLines("Pulling county-FIPS code mappings data...")

# Saves the data source URL and output location to variables.
cty_fips_url_in <- "https://www.bls.gov/lau/laucnty16.xlsx"
cty_fips_path_out <- "data/processed/reference_data/county_fips_mappings.csv"

cty_fips_mappings <-
	# Reads in the source XLSX (Excel) file from the URL, skipping the first 7
	# lines since they are simply descriptive info. Also only takes in the relevant
	# columns needed for this script.
	read.xlsx(
		cty_fips_url_in, 
		startRow = 7, 
		colNames = F,
		cols = 2:4
	) %>% 
	rename(
		state_fips = X1,
		cty_fips = X2,
		area = X3
	) %>% 
	mutate(
		# Replaces odd "County/city" nomenclature with just "county"
		area = str_replace(area, "County/city", "County"),
		# Extracts the county name and state abbreviation from the area.
		county = ifelse(
			area == "District of Columbia",
			"District of Columbia",
			str_extract(area, ".*(?=,)")
		),
		state = ifelse(
			county == "District of Columbia",
			"DC",
			str_extract(area, "(?<=,\\s).*")
		),
		# Constructs the 5 digit county-specific FIPS codes.
		fips_code = str_c(state_fips, cty_fips),
		area_formatted = 
			area %>% 
			str_remove_all(",") %>% 
			str_to_lower() %>% 
			str_replace_all(" |/", "-"),
		# Constructs the file path/URL for each area.
		# TO-DO: May consider making this URL just the unique FIPS code.
		county_page_filepath = 
			paste0("county-pages/", area_formatted, "-", fips_code, ".html"),
		county_page_url = 
			paste0("/", county_page_filepath)
	)

# Writes the processed data to a CSV file in the `data/processed/reference_data`
# folder.
cty_fips_mappings %>% write_csv(cty_fips_path_out)

# Pulls the available FIPS/counties that we have and uses them to filter data
# throughout the pipeline.
available_fips <- cty_fips_mappings %>% pull(fips_code)

writeLines(paste0("Creating unique data folders for ", length(available_fips), " available counties within county-data/counties/..."))

for (fips_code in available_fips) {
	dir.create(str_c("county-data/counties/", fips_code), showWarnings = F)
}

# Selects data columns relevant to Javascript search function.
cty_fips_mappings_json <- 
	cty_fips_mappings %>% 
	select(state, area, county_page_url)

# Transforms relevant columns from R dataframe to JSON list.
json_for_search <- 
	cty_fips_mappings_json %>% 
	group_by(state) %>% 
	nest() %>% 
	pivot_wider(names_from = state, values_from = data) %>% 
	toJSON(pretty = T)

# Writes JSON for JS search to relevant file path.
writeLines(
	json_for_search,
	"county-data/json/json_for_search.json"
)

rm(cty_fips_mappings, cty_fips_mappings_json, cty_fips_path_out, cty_fips_url_in)

writeLines("County-FIPS code mappings pulled and processed.")
writeLines("County data is stored in data/processed/reference_data/.")
writeLines("JSON data for JS search function is stored at county-data/json/json_for_search.json.")

# End timer
toc()
writeLines("")