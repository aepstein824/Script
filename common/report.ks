@LAZYGLOBAL OFF.

function reportCreate {
    parameter keys.

    local report to lexicon().

    set report:gui to gui(200).
    set report:keyToVal to lexicon().
    local hlayout to report:gui:addhlayout().
    set report:names to hlayout:addvlayout().
    set report:vals to hlayout:addvlayout().

    for k in keys {
        report:names:addlabel(k).
        local val to report:vals:addlabel(k).
        set report["keyToVal"][k] to val.
    }

    return report.
}