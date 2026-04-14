(* Test ambient span tracking via thread-local-storage provider *)

open Test_trace_common

let ( let@ ) = ( @@ )

let () =
  print_endline "=== ambient span (TLS) ===";
  Trace_thread_local_storage.setup ();
  let coll = make_recorder () in
  let@ () = Trace_core.with_setup_collector coll in

  Printf.printf "before any span: %s\n" (current_name ());

  let@ _outer = Trace_core.with_span ~__FILE__ ~__LINE__ "outer" in
  Printf.printf "in outer: %s\n" (current_name ());

  (* inner span is scoped to just the one printf *)
  (let@ _inner = Trace_core.with_span ~__FILE__ ~__LINE__ "inner" in
   ignore _inner;
   Printf.printf "in inner: %s\n" (current_name ()));

  (* inner has exited, outer span is restored *)
  Printf.printf "after inner exits: %s\n" (current_name ())
