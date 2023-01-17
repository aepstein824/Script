@LAZYGLOBAL OFF.

runOncePath("0:common/operations.ks").

global kPhases to Lexicon().
set kPhases:startInc to 0.
set kPhases:stopInc to 0.
set kPhases:phase to -1.

function shouldPhase {
    parameter p.

    if kPhases:phase >= 0 {
        return p = kPhases:phase.
    }

    return kPhases:startInc <= p and p <= kPhases:stopInc.
}

