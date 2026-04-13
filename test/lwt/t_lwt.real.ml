(* Test ambient span tracking via Lwt key provider *)

open Test_trace_common

let ( let@ ) = ( @@ )

let () =
  print_endline "=== ambient span (Lwt) ===";
  Trace_core.set_ambient_context_provider Trace_lwt.ambient_span_provider;
  let coll = make_recorder () in
  let@ () = Trace_core.with_setup_collector coll in

  (* sync with_span works with the Lwt provider *)
  Printf.printf "before any span: %s\n" (current_name ());

  (let@ _outer = Trace_core.with_span ~__FILE__ ~__LINE__ "sync-outer" in
   Printf.printf "sync outer: %s\n" (current_name ());
   let@ _inner = Trace_core.with_span ~__FILE__ ~__LINE__ "sync-inner" in
   Printf.printf "sync inner: %s\n" (current_name ()));

  Printf.printf "after sync: %s\n" (current_name ());

  (* Lwt-specific tests *)
  Lwt_main.run
    (let open Lwt.Syntax in
     (* nested Trace_lwt.with_span *)
     let* () =
       Trace_lwt.with_span ~__FILE__ ~__LINE__ "lwt-outer" (fun _outer ->
           Printf.printf "lwt outer: %s\n" (current_name ());
           let* () =
             Trace_lwt.with_span ~__FILE__ ~__LINE__ "lwt-inner" (fun _inner ->
                 Printf.printf "lwt inner: %s\n" (current_name ());
                 Lwt.return_unit)
           in
           Printf.printf "after lwt inner: %s\n" (current_name ());
           Lwt.return_unit)
     in
     Printf.printf "after lwt outer: %s\n" (current_name ());

     (* context survives Lwt.bind chain *)
     let* () =
       Trace_lwt.with_span ~__FILE__ ~__LINE__ "bind-test" (fun _sp ->
           let* () = Lwt.return_unit in
           let* () = Lwt.return_unit in
           Printf.printf "after binds: %s\n" (current_name ());
           Lwt.return_unit)
     in

     Lwt.return_unit)
