(** Shared test utilities for ambient span tests. *)

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
