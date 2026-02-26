(* Test ambient span tracking via thread-local-storage provider *)

let ( let@ ) = ( @@ )

(* Unique span type so we can identify spans by name *)
type Trace_core.span += Named of string

let make_recorder () =
  let open Trace_core.Collector in
  let cbs =
    Callbacks.make
      ~enter_span:(fun
          ()
          ~__FUNCTION__:_
          ~__FILE__:_
          ~__LINE__:_
          ~level:_
          ~params:_
          ~data:_
          ~parent:_
          name
        -> Named name)
      ~exit_span:(fun () _sp -> ())
      ~add_data_to_span:(fun () _sp _data -> ())
      ~message:(fun () ~level:_ ~params:_ ~data:_ ~span:_ _msg -> ())
      ~metric:(fun () ~level:_ ~params:_ ~data:_ _name _m -> ())
      ()
  in
  C_some ((), cbs)

let current_name () =
  match Trace_core.current_span () with
  | None -> "none"
  | Some (Named s) -> s
  | Some _ -> "<other>"

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
