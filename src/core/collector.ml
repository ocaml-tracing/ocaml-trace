(** A global collector.

    The collector, if present, is responsible for collecting messages and spans,
    and storing them, recording them, forward them, or offering them to other
    services and processes. *)

open Types

type span += Span_dummy

(** A fake span that never emits data. All collectors should handle this span by
    doing nothing. *)
let dummy_span : span = Span_dummy

module Callbacks = struct
  type 'st t = {
    enter_span:
      'st ->
      __FUNCTION__:string option ->
      __FILE__:string ->
      __LINE__:int ->
      level:Level.t ->
      params:extension_parameter list ->
      data:(string * user_data) list ->
      parent:parent ->
      string ->
      span;
        (** Enter a span *)
    exit_span: 'st -> span -> unit;
        (** Exit a span. Must be called exactly once per span. Additional
            constraints on nesting, threads, etc. vary per collector. *)
    add_data_to_span: 'st -> span -> (string * user_data) list -> unit;
    enabled: 'st -> Level.t -> bool;
        (** Is the collector accepting spans/messages/metrics with this level?
        *)
    message:
      'st ->
      level:Level.t ->
      params:extension_parameter list ->
      data:(string * user_data) list ->
      span:span option ->
      string ->
      unit;
        (** Emit a message or log *)
    metric:
      'st ->
      level:Level.t ->
      params:extension_parameter list ->
      data:(string * user_data) list ->
      string ->
      metric ->
      unit;
        (** Metric . *)
    extension: 'st -> level:Level.t -> extension_event -> unit;
        (** Collector-specific extension. It now has a level as well. *)
    init: 'st -> unit;  (** Called on initialization *)
    shutdown: 'st -> unit;
        (** Shutdown collector, possibly waiting for it to finish sending data.
        *)
  }
  (** Callbacks taking a state ['st] *)

  (** Helper to create backends in a future-proof way *)
  let make ?(enabled = fun _ _ -> true) ~enter_span ~exit_span ~add_data_to_span
      ~message ~metric ?(extension = fun _ ~level:_ _ -> ()) ?(init = ignore)
      ?(shutdown = ignore) () : _ t =
    {
      enter_span;
      exit_span;
      add_data_to_span;
      enabled;
      message;
      metric;
      extension;
      init;
      shutdown;
    }
end

(** Definition of a collector.

    This is only relevant to implementors of tracing backends; to instrument
    your code you only need to look at the {!Trace} module.

    The definition changed since 0.11 to a record of callbacks + a state *)
type t =
  | C_none  (** No collector. *)
  | C_some : 'st * 'st Callbacks.t -> t
      (** Collector with a state and some callbacks. *)

let[@inline] is_some = function
  | C_none -> false
  | C_some _ -> true
