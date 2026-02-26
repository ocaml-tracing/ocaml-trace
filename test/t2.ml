module Trace = Trace_core

let ( let@ ) = ( @@ )

let rec fib x =
  let%trace () = "fib" in
  if x <= 2 then
    1
  else
    fib (x - 1) + fib (x - 2)

let%trace rec fib2 x =
  if x <= 2 then
    1
  else
    fib2 (x - 1) + fib2 (x - 2)

let () =
  Trace_tef.Private_.mock_all_ ();
  let@ () = Trace_tef.with_setup ~out:`Stdout () in

  Trace_core.set_process_name "main";
  Trace_core.set_thread_name "t1";

  let x = fib 13 in
  assert (x = 233);

  let x = fib2 13 in
  assert (x = 233);
  ()
