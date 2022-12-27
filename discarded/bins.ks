@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").

// Note that N divisions split the number line into N+1
// regions.
function binsCreate {
    parameter rows, cols.

    local data to list().
    local valid to list().
    for i in range(rows:length() + 1) {
        local row to list().
        local vrow to list().
        for j in range(cols:length() + 1) {
            row:add(zeroV:vec).
            vrow:add(false).
        }
        data:add(row).
        valid:add(vrow).
    }

    return lexicon(
        "rows", rows,
        "cols", cols,
        "data", data,
        "valid", valid
    ).
}

function binsGetPoint {
    parameter bins, point.

    local inds to binsPointToIndices(bins, point).
    local data to bins:data.

    return data[inds[0]][inds[1]].
}

function binsSet {
    parameter bins, point.

    local inds to binsPointToIndices(bins, point).
    local valid to bins:valid.
    local data to bins:data.

    set valid[inds[0]][inds[1]] to true.
    set data[inds[0]][inds[1]] to point.
}

function binsGetRowData {
    parameter bins, row.

    local i to binsKeyToIndex(bins:rows, row).
    local data to list().
    local rowData to bins:data[i].
    
    for j in range(rowData:length()) {
        if bins:valid[i][j] {
            data:add(rowData[j]).
        }
    }
    return data.
}

// Actual data has one more elem than keys.
function binsKeyToIndex {
    parameter keys, key.

    local i to 0.
    until i = keys:length() {
        if key < keys[i] {
            break.
        }
        set i to i + 1.
    }
    return i.
}

function binsPointToIndices {
    parameter bins, point.                                    
    local rows to bins:rows.
    local cols to bins:cols.

    local i to binsKeyToIndex(rows, point:x).
    local j to binsKeyToIndex(cols, point:y).

    return list(i, j). 
}


// Another failed flight model
// binsSet(bins, v(airspeed, aoa, cl)).
// local rowData to binsGetRowData(bins, airspeed).
// print rowData.

// local sumX to 0.
// local sumX2 to 0.
// local sumY to 0.
// local sumXY to 0.
// local count to rowData:length().
// if count > 1 {
//     for d in rowData {
//         local x to d:y.
//         local y to d:z.
//         set sumX to sumX + x.
//         set sumX2 to sumX2 + x ^ 2.
//         set sumY to sumY + y.
//         set sumXY to sumXY + (x * y).
//     }
//     local m to (count * sumXY - sumX * sumY) 
//         / (count * sumX2 - sumX ^ 2).
//     local b to (sumY - m * sumX) / count.
//     local aoaPred to (cl - b) / m.
//     print "lift " + lift.
//     print "m " + m.
//     print "b " + b.
// }

