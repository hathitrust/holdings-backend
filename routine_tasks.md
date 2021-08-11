# Steps for performing routine print holdings tasks

## Scrub process (old):

Updated the [confluence page on scrubbing](https://tools.lib.umich.edu/confluence/display/LSO/HathiTrust+Print+Holdings+training). It's a lot, but it's what it is. Read section "2.1 Scrubbing" down to but but not including section "2.2 Estimating".

## Run estimate:

The first step is usually to receive or be mentioned on a JIRA ticket by Stewart, Melissa, asking you to run an estimate.

Download and scrub the relevant files. If they are OK, proceed. If not, alert & abort.

Extract all the OCNs from the resulting HT003-files to a single file and put in /htprep/holdings/estimates/. This path is called $path_to_ocns in the example below.

Spin up a pod that writes to a text file under /htprep/holdings/estimates/. The path to this file is called $output_path in the example below.

```
bash client_pod.sh podname-yyyymmdd bash -c \
  'bundle exec ruby bin/compile_estimated_IC_costs.rb  $path_to_ocns > $output_path'
```

When the pod is done, copy the contents in $output_path to the JIRA ticket as an INTERNAL response.

There used to be a step where output from the estimate included cost-per-h that made a graph, but that is currently not available.

## Load holdings (until we switch to autoscrub):

If not already scrubbed, scrub.

Copy scrubbed HT003-files to /htprep/holdings/loadfiles/ . This is supposed to contain all the current loaded data.

Copy the files you want to load to /htprep/holdings/loads/YYYYMMDD/ .
Prep them (sort, add uuid, split) with:

```
bash client_pod.sh load-prep-YYYYMMDD bash -c \
  'bash bin/prep_loadfiles.sh /htprep/holdings/loads/YYYYMMDD /htprep/holdings/loads/YYYYMMDD/chunks'
```

That will put the prepped files in /htprep/holdings/loads/YYYYMMDD/chunks/ .

Now spin up a pod for each chunk:

```
for f in $(eval echo "a"{"a".."p"}); do
  bash client_pod.sh load-YYYYMMDD-$f bundle exec ruby bin/add_print_holdings.rb \ 
    /htprep/holdings/loads/YYYYMMDD/chunks/split_$f.tsv &
done
```

Adjust the aa..ap range if you change the number of chunks.

## Run a cost report:

Using https://github.com/hathitrust/ht_kubernetes, replacing XYZ and YYYYMMDD with appropriate values:

```
bash client_pod.sh costreport-XYZ \ 
  bash -c 'bundle exec ruby bin/compile_cost_reports.rb > \ 
  /htprep/holdings/costreports/YYYY/costreport_YYYYMMDD.tsv'
```

Please do not stray from the naming convention, as that comes into play later when cost_changes.sh generates the historical comparison files.

## Prepare cost report Google Sheet for Mike

Copy the output file from the step "Run a cost report" to Google Drive.
Open a new Google Sheet, make a tab named "Raw".
Into Raw, copy the table-y parts of the cost report (skip the first couple of text lines for now).
Set permissions on Raw so that nobody else can edit it. This is so that nobody accidentally edits the data, or if you mess something up and want to revert/compare to the original. Don't mess with this tab any more. It'll look ugly but that's OK.

Copy the first couple of text-y lines of the original file into a new tab called "CalculationDetails".

Make a new tab named "Cost" in the same report with the same number of rows and cols as Raw. Set cell A1 in Cost to "=Raw!A1" and copy this to all cells in Cost, so that each cell is a live copy of the corresponding cell in Raw. Apply "Format as currency" (the dollar sign button) on all columns in Cost except member_id and weight.

Add 3 lines at the bottom of Cost, and label them in col A as:

```
Total
Target
Total - Target
```

For Total, sum up each column.
For target, set the cell in the H column to equal the "Target Cost" value from CalculationDetails. Leave the rest blank.

For "Total - Target", in row H enter formula =Hi-Hj where i and j are the 2 rows above. This gives us by how much we missed the target.

Add 4 more tabs to the sheet, and name them:

```
Totals
Diffs
Diffs_pct
HiLites
```

To get the data with which to populate these tabs do (replace YYYYMMDD and YYYY as appriopriate):

```
bash client_pod.sh cost-changes-YYYYMMDD \
  bash bin/cost_changes.sh /htprep/holdings/costreports /htprep/holdings/costreports/YYYY
```

cost_changes.sh takes 2 dirs, the first being the input dir under which we'll (recursively) look for files matching costreport-YYYYMMDD.tsv, and the second being the output directory to which 4 files are written:

```
append_totals_YYYYMMDD.tsv
diff_totals_YYYYMMDD.tsv
diff_percent_totals_YYYYMMDD.tsv
hilites_YYYYMMDD.tsv
```

Paste each output file into the corresponding tab. In HiLites check for anomalous values, and add a Notes column noting which members were updated/added etc. since the last report.
