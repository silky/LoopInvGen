open Base

let () =
  let zpath = if (Array.length Sys.argv) > 1 then Sys.argv.(1)
              else String.strip Stdio.(In_channel.input_line_exn stdin)
   in Alcotest.run ~argv:[| "zpath" |] "LoopInvGen"
                   [ "Test_BFL", Test_BFL.all
                   ; "Test_Synthesizer", Test_Synthesizer.all
                   ; "Test_PIE", Test_PIE.all
                   ; "Test_ZProc", (Test_ZProc.all ~zpath)
                   ; "Test_ZProc", (Test_ZProc.all ~zpath)
                   ]
