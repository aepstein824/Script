@LAZYGLOBAL OFF.

runOncePath("0:common/math.ks").
runOncePath("0:common/operations.ks").

local kBound to 0.1.

function tableCreate {
    parameter rows, cols, bound to kBound.

    local cells to list().

    for r in rows {
        local row to list().
        for c in cols {
            row:add(v(0, 0, 0)).            
        }
        cells:add(row).
    }

    return lexicon(
        "rows", rows,
        "cols", cols,
        "cells", cells,
        "bound", bound
    ).
}

function tableKeyInds {
    parameter keys, key, bound.

    local leftI to 0.
    local rightI to keys:length - 1.
    for i in range(keys:length) {
        if key <= (keys[i] + bound) {
            set rightI to i.
            if key >= (keys[i] - bound) {
                // also snap the left this value
                set leftI to i.
            }
            break.
        }
        set leftI to i.
    }

    return list(leftI, rightI).
}

function tableRatio {
    parameter keys, key, low, high.

    if low = high {
        return 1.
    }

    return invLerp(key, keys[low], keys[high]).
}

function tableLRUD {
    parameter rows, cols, row, col, bound.

    local lr to tableKeyInds(rows, row, bound).
    local ud to tableKeyInds(cols, col, bound).

    return mergeList(lr, ud).
}

function tableUpdate {
    parameter table, row, col, value.

    local rows to table:rows.
    local cols to table:cols.
    local cells to table:cells.
    local bound to table:bound.

    local lrud to tableLRUD(rows, cols, row, col, bound).

    local left to lrud[0].
    local right to lrud[1].
    local upp to lrud[2].
    local down to lrud[3].

    local lRatio to tableRatio(rows, row, left, right).
    local rRatio to 1 - lRatio.
    local uRatio to tableRatio(cols, col, upp, down).
    local dRatio to 1 - uRatio.

    local corners to list(cells[left][upp], cells[left][down],
        cells[right][upp], cells[right][down]).
    local ratios to list(lRatio * uRatio, lRatio * dRatio,
        rRatio * uRatio, rRatio * dRatio).
    for i in range(4) {
        local corner to corners[i].
        local addedCount to ratios[i].
        if addedCount > 0 {
            local existingCount to corner:y.
            set corner:y to addedCount + existingCount.
            set corner:x to (existingCount * corner:x + addedCount * value)
                / corner:y.
        }
    }
}

function tableGet {
    parameter table, row, col.

    local rows to table:rows.
    local cols to table:cols.
    local cells to table:cells.
    local bound to table:bound.

    local lrud to tableLRUD(rows, cols, row, col, bound).
    local left to lrud[0].
    local right to lrud[1].
    local upp to lrud[2].
    local down to lrud[3].

    local lRatio to tableRatio(rows, row, left, right).
    local rRatio to 1 - lRatio.
    local uRatio to tableRatio(cols, col, upp, down).
    local dRatio to 1 - uRatio.

    local luc to cells[left][upp].
    local ldc to cells[left][down].
    local ruc to cells[right][upp].
    local rdc to cells[right][down].

    local dataTotal to 0.
    local dataCount to 0.
    for cell in list(luc, ldc, ruc, rdc) {
        if cell:y > 0 {
            set dataTotal to dataTotal + cell:x.
            set dataCount to dataCount + 1.
        }
    }
    if dataCount = 0 {
        return 0.
    }
    local dataAvg to dataTotal / dataCount.

    local luv to choose luc:x if luc:y > 0 else dataAvg.
    local ldv to choose ldc:x if ldc:y > 0 else dataAvg.
    local ruv to choose ruc:x if ruc:y > 0 else dataAvg.
    local rdv to choose rdc:x if rdc:y > 0 else dataAvg.

    local leftVal to uRatio * luv + dRatio * ldv.
    local rightVal to uRatio * ruv + dRatio * rdv.
    local val to lRatio * leftVal + rRatio * rightVal.

    return val.
}