(** Simple collector that emits trace events via Runtime_events.

    @since 0.12 *)

(** {2 Event types for decoding} *)

module String_type : sig
  val ty : string Runtime_events.Type.t
end

module String_int : sig
  val ty : (string * int) Runtime_events.Type.t
end

module String_float : sig
  val ty : (string * float) Runtime_events.Type.t
end

(** Custom events *)
module Events : sig
  type Runtime_events.User.tag +=
    | Tag_span_enter
    | Tag_span_exit
    | Tag_message
    | Tag_metric_int
    | Tag_metric_float

  val span_enter_event : string Runtime_events.User.t
  val span_exit_event : string Runtime_events.User.t
  val message_event : string Runtime_events.User.t
  val metric_int_event : (string * int) Runtime_events.User.t
  val metric_float_event : (string * float) Runtime_events.User.t
end

(** {2 Collector} *)

val collector : ?start_events:bool -> unit -> Trace_core.Collector.t
(** [collector ~start_events ()] creates a new collector that emits events via
    Runtime_events.

    @param start_events
      if [true] (default), automatically call [Runtime_events.start()] when the
      collector is initialized. *)

val setup : ?start_events:bool -> unit -> unit
(** [setup ~start_events ()] sets up the Runtime_events collector as the global
    collector.

    See {!collector} *)

val with_setup : ?start_events:bool -> (unit -> 'a) -> 'a
(** [with_setup ~start_events f] runs [f ()] with the Runtime_events collector
    enabled, and shuts it down when done.

    See {!collector} *)
