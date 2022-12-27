@LAZYGLOBAL OFF.

function differCreate {
    parameter initValues, t.

    local derivatives to list().

    for val in initValues {
        // get zero in the correct type
        derivatives:add(val - val).
    }

    return lexicon(
        "Last", initValues,
        "D", derivatives,
        "T", t
    ).
}

function differUpdate {
    parameter differ, newValues, t.

    local dt to t - differ:T.
    local oldValues to differ:Last.
    local derivatives to list().

    for i in range(newValues:length) {
        local new to newValues[i].
        local old to oldValues[i].
        derivatives:add((new - old) / dt).
    }

    set differ:Last to newValues.
    set differ:T to t.
    set differ:D to derivatives.

    return derivatives.
}