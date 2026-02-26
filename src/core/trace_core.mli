(** Main tracing interface.

    This interface is intended to be lightweight and usable in both libraries
    and applications. It has very low overhead if no {!Collector.t} is
    installed. *)

include module type of Types
module Collector = Collector
module Level = Level
module Ambient_span_provider = Ambient_span_provider

(**/**)

(* no guarantee of stability *)
module Internal_ : sig
  module Atomic_ = Atomic_
end

(**/**)

(** {2 Tracing} *)

val enabled : unit -> bool
(** Is there a collector?

    This is fast, so that the traced program can check it before creating any
    span or message. *)

val get_default_level : unit -> Level.t
(** Current default level for spans.
    @since 0.7 *)

val set_default_level : Level.t -> unit
(** Set level used for spans that do not specify it. The default default value
    is [Level.Trace].
    @since 0.7 *)

val with_span :
  ?level:Level.t ->
  ?__FUNCTION__:string ->
  __FILE__:string ->
  __LINE__:int ->
  ?parent:span option ->
  ?params:extension_parameter list ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  (span -> 'a) ->
  'a
(** [with_span ~__FILE__ ~__LINE__ name f] enters a new span [sp], and calls
    [f sp]. [sp] might be a dummy span if no collector is installed. When [f sp]
    returns or raises, the span [sp] is exited.

    This is the recommended way to instrument most code.

    @param level
      optional level for this span. since 0.7. Default is set via
      {!set_default_level}.
    @param parent the span's parent, if any. since 0.11.
    @param params
      extension parameters, used to communicate additional information to the
      collector. It might be collector-specific. since 0.11.

    Depending on the collector, this might clash with some forms of cooperative
    concurrency in which [with_span (fun span -> …)] might contain a yield
    point. Effect-based fibers, etc. might not play well with this style of
    spans on some or all backends. If you use cooperative concurrency, a safer
    alternative can be {!enter_span}. *)

val enter_span :
  ?level:Level.t ->
  ?__FUNCTION__:string ->
  __FILE__:string ->
  __LINE__:int ->
  ?flavor:[ `Sync | `Async ] ->
  ?parent:span option ->
  ?params:extension_parameter list ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  span
(** Enter a span manually. This means the caller is responsible for exiting the
    span exactly once on every path that exits the current scope. The context
    must be passed to the exit function as is.

    @param level
      optional level for this span. since 0.7. Default is set via
      {!set_default_level}.
    @param parent the span's parent, if any. since 0.11.
    @param params see {!with_span}. *)

val exit_span : span -> unit
(** Exit a span manually. Spans must be nested correctly (ie form a stack or
    tree).

    For some collectors, [enter_span] and [exit_span] must run on the same
    thread (e.g. Tracy). For some others, it doesn't matter. *)

val add_data_to_span : span -> (string * user_data) list -> unit
(** Add structured data to the given active span (see {!with_span}). Behavior is
    not specified if the span has been exited.
    @since 0.4 *)

val message :
  ?level:Level.t ->
  ?span:span ->
  ?params:extension_parameter list ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  unit
(** [message msg] logs a message [msg] (if a collector is installed). Additional
    metadata can be provided.
    @param level
      optional level for this span. since 0.7. Default is set via
      {!set_default_level}.
    @param span
      the surrounding span, if any. This might be ignored by the collector.
    @param params
      extension parameters, used to communicate additional information to the
      collector. It might be collector-specific. since 0.11. *)

val messagef :
  ?level:Level.t ->
  ?span:span ->
  ?params:extension_parameter list ->
  ?data:(unit -> (string * user_data) list) ->
  ((('a, Format.formatter, unit, unit) format4 -> 'a) -> unit) ->
  unit
(** [messagef (fun k->k"hello %s %d!" "world" 42)] is like
    [message "hello world 42!"] but only computes the string formatting if a
    collector is installed.

    See {!message} for a description of the other arguments. *)

val set_thread_name : string -> unit
(** Give a name to the current thread. This might be used by the collector to
    display traces in a more informative way.

    Uses {!Core_ext.Extension_set_thread_name} since 0.11 *)

val set_process_name : string -> unit
(** Give a name to the current process. This might be used by the collector to
    display traces in a more informative way.

    Uses {!Core_ext.Extension_set_process_name} since 0.11 *)

val metric :
  ?level:Level.t ->
  ?params:extension_parameter list ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  metric ->
  unit
(** Emit a metric. Metrics are an extensible type, each collector might support
    a different subset.
    @since 0.11 *)

val counter_int :
  ?level:Level.t ->
  ?params:extension_parameter list ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  int ->
  unit
(** Emit a counter of type [int] via {!metric}. Counters represent the evolution
    of some quantity over time.
    @param level
      optional level for this span. since 0.7. Default is set via
      {!set_default_level}.
    @param data metadata for this metric (since 0.4) *)

val counter_float :
  ?level:Level.t ->
  ?params:extension_parameter list ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  float ->
  unit
(** Emit a counter of type [float] via {!metric}. See {!counter_int} for more
    details.
    @param level
      optional level for this span. since 0.7. Default is set via
      {!set_default_level}.
    @param data metadata for this metric (since 0.4) *)

val current_span : unit -> span option
(** Access the current span from some ambient scope, {b if supported}. This is
    only supported if a {!Ambient_span_provider} has been set up.
    @since NEXT_RELEASE *)

val with_current_span_set_to : span -> (span -> 'a) -> 'a
(** [with_current_span_set_to span f] sets the span as current span, enters
    [f span], and restores the previous current span (if any).

    This is only supported if a {!Ambient_span_provider} has been set up,
    otherwise it is a no-op.

    Automatically called by {!with_span}.

    @since NEXT_RELEASE *)

(** {2 Collector} *)

type collector = Collector.t
(** An event collector. See {!Collector} for more details. *)

val setup_collector : collector -> unit
(** [setup_collector c] installs [c] as the current collector.
    @raise Invalid_argument if there already is an established collector. *)

val get_current_level : unit -> Level.t
(** Get current level. This is only meaningful if a collector was set up with
    {!setup_collector}.
    @since 0.7 *)

val set_current_level : Level.t -> unit
(** Set the current level of tracing. This only has a visible effect if a
    collector was installed with {!setup_collector}.
    @since 0.7 *)

val shutdown : unit -> unit
(** [shutdown ()] shutdowns the current collector, if one was installed, and
    waits for it to terminate before returning. *)

val with_setup_collector : Collector.t -> (unit -> 'a) -> 'a
(** [with_setup_collector c f] installs [c], calls [f()], and shutdowns [c] once
    [f()] is done.
    @since 0.11 *)

(** {2 ambient span provider} *)

val set_ambient_context_provider : Ambient_span_provider.t -> unit
(** Install a provider for {!current_span} and {!with_current_span_set_to}. The
    default provider does nothing (ie [current_span ()] is always [None]).
    @since NEXT_RELEASE *)

(** {2 Extensions} *)

type extension_event = Types.extension_event = ..
(** Extension event
    @since 0.8 *)

val extension_event : ?level:Level.t -> extension_event -> unit
(** Trigger an extension event, whose meaning depends on the library that
    defines it. Some collectors will simply ignore it. This does nothing if no
    collector is setup.
    @param level filtering level, since 0.11
    @since 0.8 *)

(** {2 Core extensions} *)

module Core_ext = Core_ext

(** {2 Deprecated} *)

[@@@ocaml.alert "-deprecated"]

val enter_manual_span :
  parent:explicit_span_ctx option ->
  ?flavor:[ `Sync | `Async ] ->
  ?level:Level.t ->
  ?__FUNCTION__:string ->
  __FILE__:string ->
  __LINE__:int ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  explicit_span
[@@deprecated "use enter_span"]

val enter_manual_sub_span :
  parent:explicit_span ->
  ?flavor:[ `Sync | `Async ] ->
  ?level:Level.t ->
  ?__FUNCTION__:string ->
  __FILE__:string ->
  __LINE__:int ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  explicit_span
[@@deprecated "use enter_span"]
(** @deprecated since 0.10, use {!enter_span} *)

val enter_manual_toplevel_span :
  ?flavor:[ `Sync | `Async ] ->
  ?level:Level.t ->
  ?__FUNCTION__:string ->
  __FILE__:string ->
  __LINE__:int ->
  ?data:(unit -> (string * user_data) list) ->
  string ->
  explicit_span
[@@deprecated "use enter_span"]
(** @deprecated since 0.10 use {!enter_span} *)

val exit_manual_span : explicit_span -> unit
[@@deprecated "use exit_span"]
(** @deprecated since 0.10 use {!exit_span} *)

val add_data_to_manual_span : explicit_span -> (string * user_data) list -> unit
[@@deprecated "use add_data_to_span"]
(** @deprecated since 0.10 use {!add_data_to_span} *)

[@@@ocaml.alert "+deprecated"]
