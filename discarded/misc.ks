// function opsLabRestore {
//     wait 1.
//     local labPart to ship:partsnamedpattern("Large.Crewed.Lab")[0].
//     for modName in labPart:modules {
//         local mod to labPart:getmodule(modname).
//         print mod.
//     }

//     The container feature of the lab seems to work, but might have been
//     removed from the Lab UI. It doesn't have UI for reviewing the
//     experiments. Too spooky for me.
//     local containerMod to labPart:getmodule("ModuleScienceContainer").
//     containerMod:doaction("collect all", true).

//     This is unreliable, and the modules have reset actions that work better.
//     local resetMod to labPart:getmodule("ModuleScienceLab").
//     for event in resetMod:alleventnames {
//         if event:contains("clean") {
//             print " Cleaning experiments with lab.".
//             resetMod:doevent(event).
//         } 
//     }
// }