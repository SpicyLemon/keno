// Adds ability to get the active sheet as JSON.

// The different options for output format.
var FORMAT_PRETTY    = 'Pretty';       // Standard pretty-print output.
var FORMAT_ONELINE   = 'One-line';     // All on one line.
var FORMAT_MULTILINE = 'Multi-line';   // Each object on a single line.

// The different options for how to handle null cells.
var EMPTY_CELL_OMIT = 'Omit';                     // Do not include the key in the object.
var EMPTY_CELL_NULL = 'null';                     // Include the key in the object, and set the value to null.
var EMPTY_CELL_EMPTY_STRING = 'Empty String';     // Include the key in the object, and set the value to ''.

// Defaults for this particular spreadsheet.
var DEFAULT_OPTIONS = {
  format: FORMAT_MULTILINE,
  empty_cell: EMPTY_CELL_OMIT,
  preserve_header_case: true,
  spaces_per_tab: 2
};




// Gets run when the spreadsheet is opened.
// Adds the "Create JSON" option to the menu at the top of the sheet.
function onOpen() {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var menuEntries = [
    {name: "Create JSON of current sheet.", functionName: "createJsonOfActiveSheet"}
  ];
  ss.addMenu("Create JSON", menuEntries);
}

// Used to display the JSON result.
// Arguments:
//   - text: The text to display.
function displayText(text) {
  var output = HtmlService.createHtmlOutput("<textarea style='width:100%;' rows='20'>" + text + "</textarea>");
  output.setWidth(400)
  output.setHeight(300);
  SpreadsheetApp.getUi().showModalDialog(output, 'Created JSON');
}


// The function that gets called when the menu option is selected in Sheets.
// Arguments:
//   - e: The event (possibly used for future option selection).
function createJsonOfActiveSheet(e) {
  var ss = SpreadsheetApp.getActiveSpreadsheet();
  var sheet = ss.getActiveSheet();
  var options = getOptions_(e);
  var rowsData = getRowsData_(sheet, options);
  var json = makeJSON_(rowsData, options);
  displayText(json);
}

// Get the options to use in all this stuff.
// Starts with the defaults (defined above in DEFAULT_OPTIONS),
// then applies any passed in parameters in the e.
// Arguments:
//   - e: The event (possibly used for future option selection).
function getOptions_(e) {
  var options = {}
  for (var prop in DEFAULT_OPTIONS) {
    if (DEFAULT_OPTIONS.hasOwnProperty(prop)) {
      options[prop] = e && e.parameter && prop in e.parameter ? e.parameter[prop] : DEFAULT_OPTIONS[prop];
    }
  };

  Logger.log(options);
  return options;
}

// Converts a sheet into an array of objects.
// Each object represents a row.
// The object keys are the column headers.
// Arguments:
//   - sheet: the sheet object that contains the data to be processed
//   - options: An object containing desired option values.
// Returns an array of objects.
function getRowsData_(sheet, options) {
  var headersRange = sheet.getRange(1, 1, 1, sheet.getMaxColumns());
  var headers = headersRange.getValues()[0];
  var dataRange = sheet.getRange(2, 1, sheet.getMaxRows(), sheet.getMaxColumns());
  var objects = getObjects_(dataRange.getValues(), normalizeHeaders_(headers, options), options);
  return objects;
}

// Converts an array of objects into JSON.
// Arguments:
//   - objects: The array of objects to convert.
//   - options: An object containing desired option values.
// Options:
//   - format: The desired format type.
//   - spaces_per_tab: The number of spaces to use per 'tab'.
// Returns a big long, possibly multi-line String.
function makeJSON_(objects, options) {
  if (options.format === FORMAT_PRETTY) {
    var jsonString = JSON.stringify(objects, null, options.spaces_per_tab);
  } else if (options.format === FORMAT_ONELINE) {
    var jsonString = JSON.stringify(objects);
  } else if (options.format === FORMAT_MULTILINE) {
    var tab = repeat(' ', options.spaces_per_tab);
    var jsonString = '[';
    var isFirst = true;
    objects.forEach(function(obj) {
      if (isFirst) {
        isFirst = false;
      } else {
        jsonString = jsonString + ','
      }
      jsonString = jsonString + '\n' + tab + JSON.stringify(obj);
    });
    jsonString = jsonString + '\n]';
  }
  return jsonString;
}


// For every row of data in data, generates an object that contains the data. Names of
// object fields are defined in keys.
// Arguments:
//   - data: JavaScript 2d array
//   - keys: An array of Strings that define the property names for the objects to create
//   - options: An object containing desired option values.
// Options:
//   - empty_cell: How to handle empty cells.
// Returns an array of objects.
function getObjects_(data, keys, options) {
  var objects = [];
  for (var i = 0; i < data.length; ++i) {
    var object = {};
    var hasData = false;
    for (var j = 0; j < data[i].length; ++j) {
      var cellData = data[i][j];
      if (isCellEmpty_(cellData)) {
        if (options.empty_cell === EMPTY_CELL_OMIT) {
          continue;
        } else if (options.empty_cell === EMPTY_CELL_NULL) {
          cellData = null;
        } else if (options.empty_cell === EMPTY_CELL_EMPTY_STRING) {
          cellData = '';
        }
      }
      object[keys[j]] = cellData;
      hasData = true;
    }
    if (hasData) {
      objects.push(object);
    }
  }
  return objects;
}

// Returns an Array of normalized Strings.
// Arguments:
//   - headers: Array of Strings to normalize.
//   - options: An object containing desired option values.
// Notes:
//   - If a column does not have a header, 'key' is used.
//   - If multiple columns have the same header, '_2' will be applied to the 2nd, '_3' to the third, etc.
// Returns an array of Strings.
function normalizeHeaders_(headers, options) {
  var keys = [];
  var keysUsed = {};
  for (var i = 0; i < headers.length; ++i) {
    var key = normalizeHeader_(headers[i], options);
    if (!key || key.length === 0) {
      key = 'key';
    }
    if (keysUsed[key]) {
      var k = 2;
      var newKey = key + '_' + k;
      while (keysUsed[newKey]) {
        k += 1;
        newKey = key + '_' + k;
      }
      key = newKey;
    }
    keys.push(key);
    keysUsed[key] = true;
  }
  return keys;
}

// Normalizes a string.
// Arguments:
//   - header: String to normalize
//   - options: An object containing desired option values.
// Options:
//   - preserve_header_case -> If false, result will be lowercase. If true, letter case will not be altered.
// Examples:
//   - "First Name" -> "first_name"
//   - "Length (meters)" -> "length"
//   - "  3 weird-named-(nope) thing++  " -> "weird_named_thing"
// Returns a String.
function normalizeHeader_(header, options) {
  var retval = header.replace(/\([^\)]+\)/g, '').  // Get rid of anything wrapped in parenthesis.
                      replace(/[^\w]+/g, '_').     // Change any non-word characters to underscores.
                      replace(/^[_\d]+/, '').      // Get rid of any leading underscores and numbers.
                      replace(/[_]+$/, '');        // Get rid of any trailing underscores.
  if (!options.preserve_header_case) {
    retval = retval.toLowerCase();
  }
  return retval;
}

// Repeat a string a certain number of times.
// Arguments:
//   - str: The String to repeat
//   - n: The number of times to repeat it.
// Returns a String.
function repeat(str, n) {
  var retval = '';
  for(var i=0; i<n; i++) {
    retval = retval + str;
  }
  return retval;
}

// Returns true if the cell where cellData was read from is empty.
// Arguments:
//   - cellData: string
// Returns a boolean.
function isCellEmpty_(cellData) {
  return typeof(cellData) == "string" && cellData == "";
}
