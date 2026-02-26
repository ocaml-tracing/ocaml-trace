module Trace = Trace_core

let ( let@ ) = ( @@ )

let main () =
  let@ _sp = Trace.with_span ~__FILE__ ~__LINE__ "main" in

  let _sp1 = Trace.enter_span ~__FILE__ ~__LINE__ "sp1" in
  let _sp2 = Trace.enter_span ~__FILE__ ~__LINE__ "sp2" in
  let _sp1' = Trace.enter_span ~__FILE__ ~__LINE__ "sp1" in

  ()

let () =
  Trace_tef.Private_.mock_all_ ();
  let@ () =
    Trace.with_setup_collector
      (Trace_tef.collector ~out:`Stdout ()
      |> Trace_debug.Track_spans.track ~on_lingering_spans:(`Out stdout))
  in
  main ()
