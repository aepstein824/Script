@LAZYGLOBAL OFF.

runOncePath("0:common/operations.ks").

global kPhases to Lexicon().
set kPhases:startInc to 0.
set kPhases:stopInc to 0.

function shouldPhase {
    parameter p.
    return kPhases:startInc <= p and p <= kPhases:stopInc.
}

