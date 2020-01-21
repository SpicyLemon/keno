# keno / data_generation
Some scripts and files used to generate various large strings.

## Contents

* `combo_gen.sh` - Used to generate text that can be copy/pasted into a spreadsheet to calculate all desired combination values.
* `combos_001_to_080.json` - A JSON representation of all combination values where 1 <= n <= 80.
* `convert_to_known_combos_js.sh` - Used to convert a combos json file into the string setting knownCombos in the some javascript.
* `create-json.js.gs` - Used in Google Sheets to create a JSON string from a sheet of data.
* `keno_odds_gen.sh` - Generates text that can be copy/pasted into a spreadsheet to calculate a whole bunch of keno probabilities.

## Usage

Both `keno_odds_gen.sh` and `combo_gen.sh` generate a bunch of text meant to be copy/pasted into a spreadsheet.
They both assume you will be pasting into cell A1, but provide options that will allow you to paste it elsewhere.
They both have `--help` available.

The `keno_odds_gen.sh` script can be used to generate a (large) spreadsheet page with some probabilities.

The rest of the files/scripts were used to generate a knownCombos javascript object so that the combos could be looked up in javascript instead of calculated.

Here is the steps I took:

1.  Run this command in bash: `./combo_gen.sh -n 1-80 | pbcopy`.
1.  Create a new Google sheet to store the data.
1.  Select cell A1 and paste.
1.  Select "Split text to columns" then choose the delimiter as a semi-colon.
1.  Highlight the entire nCk (C) column and change the format to `##########################` (that's 26 digits).
1.  Copy the column.
1.  Paste the column into column D and select to "Paste Values Only."
1.  Change the format of column D to to "Plain Text".
1.  Delete column C.
1.  Under "Tools" select "Script editor".
1.  Copy the `create-json.js.gs` file and paste it into the script editor.
1.  Save the script editor file.
1.  Go back to the spreadsheet browser tab and reload the page.
1.  Wait for the "Create JSON" menu option to appear.
1.  Approve access for the script.
1.  Click on "Create JSON" -> "Create JSON of current sheet.".
1.  Once the results appear, select them all, and copy them.
1.  Run this command in bash: `pbpaste > combos_001_to_080.json`.
1.  Run this command in bash: `./convert_to_known_combos_js.sh combos_001_to_080.json | pbcopy`.
1.  Open up the html file with the javascript in question and paste in the appropriate spot.

I think I actually did the last couple steps a bit differently.
I think I wrote the script output to a file and then added the html/javascript around it (since it's so many lines).
But either way works.

