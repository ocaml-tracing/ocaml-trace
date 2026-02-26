module Trace = Trace_core

let ( let@ ) = ( @@ )

(** mini recording collector *)
let make_recorder ?(on_shutdown = fun () -> ()) () :
    Trace.Collector.t * (unit -> _ list) =
  let log = Queue.create () in
  let enter_span () ~__FUNCTION__:_ ~__FILE__:_ ~__LINE__:_ ~level:_ ~params:_
      ~data:_ ~parent:_ name =
    Queue.add (`Enter name) log;
    Trace.Collector.dummy_span
  in
  let exit_span () _sp = Queue.add `Exit log in
  let message () ~level:_ ~params:_ ~data:_ ~span:_ msg =
    Queue.add (`Msg msg) log
  in
  let metric () ~level:_ ~params:_ ~data:_ name m =
    let v =
      match m with
      | Trace.Core_ext.Metric_int n -> string_of_int n
      | Trace.Core_ext.Metric_float f -> Printf.sprintf "%.2f" f
      | _ -> "?"
    in
    Queue.add (`Metric (name, v)) log
  in
  let add_data_to_span () _sp _data = () in
  let coll =
    Trace.Collector.(
      C_some
        ( (),
          Callbacks.make ~enter_span ~exit_span ~add_data_to_span ~message
            ~metric
            ~shutdown:(fun () -> on_shutdown ())
            () ))
  in
  coll, fun () -> Queue.fold (fun acc x -> x :: acc) [] log |> List.rev

let dump events =
  List.iter
    (function
      | `Enter s -> Printf.printf "enter(%s)\n" s
      | `Exit -> print_endline "exit"
      | `Msg s -> Printf.printf "msg(%s)\n" s
      | `Metric (n, v) -> Printf.printf "metric(%s,%s)\n" n v)
    events

(* current_level acts as a ceiling: events with level <= current_level pass.
   Level order: Error < Warning < Info < Debug1 < Debug2 < Debug3 < Trace
   With current_level=Info: Error, Warning, Info pass; Debug1..Trace are filtered. *)
let () =
  print_endline "=== level filtering ===";
  let coll, get = make_recorder () in
  Trace.set_current_level Trace.Level.Info;
  let@ () = Trace.with_setup_collector coll in
  let@ _ =
    Trace.with_span ~level:Trace.Level.Error ~__FILE__ ~__LINE__ "error-span"
  in
  let@ _ =
    Trace.with_span ~level:Trace.Level.Info ~__FILE__ ~__LINE__ "info-span"
  in
  let@ _ =
    Trace.with_span ~level:Trace.Level.Debug1 ~__FILE__ ~__LINE__ "debug-span"
  in
  Trace.message ~level:Trace.Level.Warning "warn-msg";
  Trace.message ~level:Trace.Level.Trace "trace-msg";
  dump (get ());
  Trace.set_current_level Trace.Level.Trace

(* manual enter/exit round-trip
   Verify exit_span is called when using enter_span/exit_span directly. *)
let () =
  print_endline "=== manual enter/exit ===";
  let coll, get = make_recorder () in
  let@ () = Trace.with_setup_collector coll in
  let sp = Trace.enter_span ~__FILE__ ~__LINE__ "manual" in
  Trace.exit_span sp;
  dump (get ())

(* exception safety in with_span
   The span must be exited even when the body raises. *)
let () =
  print_endline "=== exception safety ===";
  let coll, get = make_recorder () in
  let@ () = Trace.with_setup_collector coll in
  (try Trace.with_span ~__FILE__ ~__LINE__ "risky" @@ fun _ -> raise Exit
   with Exit -> ());
  dump (get ())

(* no-collector behavior
   All operations are no-ops; messagef's thunk must not be called. *)
let () =
  print_endline "=== no collector ===";
  assert (not (Trace.enabled ()));
  let sp = Trace.enter_span ~__FILE__ ~__LINE__ "noop" in
  assert (sp == Trace.Collector.dummy_span);
  Trace.exit_span sp;
  let@ sp = Trace.with_span ~__FILE__ ~__LINE__ "noop2" in
  assert (sp == Trace.Collector.dummy_span);
  Trace.message "ignored";
  Trace.counter_int "ignored" 42;
  let called = ref false in
  Trace.messagef (fun k ->
      called := true;
      k "ignored");
  assert (not !called);
  print_endline "ok"

(* double setup_collector
   Installing a second collector while one is active raises Invalid_argument. *)
let () =
  print_endline "=== double setup ===";
  let coll, _ = make_recorder () in
  let coll2, _ = make_recorder () in
  let@ () = Trace.with_setup_collector coll in
  match Trace.setup_collector coll2 with
  | exception Invalid_argument msg -> Printf.printf "caught: %s\n" msg
  | () -> assert false

(* counter_float and metric *)
let () =
  print_endline "=== metrics ===";
  let coll, get = make_recorder () in
  let@ () = Trace.with_setup_collector coll in
  Trace.counter_int "my_int" 42;
  Trace.counter_float "my_float" 3.14;
  dump (get ())

(* with_setup_collector exception safety
   shutdown must be called even when the body raises. *)
let () =
  print_endline "=== with_setup_collector exception safety ===";
  let shutdown_called = ref false in
  let coll, _ =
    make_recorder ~on_shutdown:(fun () -> shutdown_called := true) ()
  in
  (try Trace.with_setup_collector coll @@ fun () -> raise Exit with Exit -> ());
  Printf.printf "shutdown called: %b\n" !shutdown_called
