(** Spall backend for Trace.

    This emits Spall binary traces (.spall), viewable at
    https://gravitymoth.com/spall/spall.html .

    Reference format: spall.h (vendored alongside this library). *)

module Collector_spall = Collector_spall
module Writer = Writer

type output =
  [ `Stdout
  | `Stderr
  | `File of string
  ]
(** Output destination for tracing. *)

val collector : out:[< output ] -> unit -> Trace_core.collector
(** Make a collector writing to the given output. *)

val setup : ?out:[ output | `Env ] -> unit -> unit
(** [setup ()] installs the Spall collector.

    @param out
      where to write events:
      - a {!output} value, or
      - [`Env] (default): enabled if the [TRACE] environment variable is set.
        ["1"] or ["true"] writes to [trace.spall]; any other value is the path;
        ["stdout"] / ["stderr"] write to those streams. *)

val with_setup : ?out:[ output | `Env ] -> unit -> (unit -> 'a) -> 'a
(** [with_setup () f] sets up the collector, calls [f()], then shuts down. *)

(**/**)

module Private_ : sig
  val mock_all_ : unit -> unit
end

(**/**)
