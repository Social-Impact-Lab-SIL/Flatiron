# Replication Package: [Insert Project Title]

This folder contains the code and instructions to replicate the findings of "[Insert Paper Title]" published in [Insert Journal/Venue].

## Data Availability Statement
- **Raw Data:** [Specify if data is public, proprietary, or provided in this repo].
- **Data Access:** [Provide link to Zenodo/OSF/OneDrive or instructions for requesting access].
- **Note:** If using restricted data, the scripts provided here assume you have placed the raw files in the `/data` folder.

## Software Requirements
- **Primary Software:** [e.g., Stata 18, R 4.3.2, Python 3.11]
- **Required Packages/Libraries:** - Stata: `ssc install reghdfe`, `ssc install ftools`
  - R: `install.packages(c("tidyverse", "fixest"))`

## Instructions
1. **Set Directory:** Open `main_file.do` (or `.R`) and update the `global` or `working_directory` path to your local machine.
2. **Run Analysis:** Execute the scripts in the following order:
   - `01_clean_data.do`
   - `02_analysis.do`
   - `03_generate_figures.do`
3. **Estimated Run Time:** [e.g., 5 minutes / 2 hours]

## List of Tables and Figures
| Exhibit | Script | Output File |
| :--- | :--- | :--- |
| Table 1 | `02_analysis.do` | `tables/table1.tex` |
| Figure 1 | `03_figures.do` | `figures/map_output.png` |

## Contact
For questions regarding this replication package, contact [Name] at [Email].
