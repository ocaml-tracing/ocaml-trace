(** Main type definitions *)

type span = ..
(** A span. Its representation is defined by the current collector.

    This representation changed in 0.11 (from [int64] to an open sum type) *)

(** Information about a span's parent span, if any.
    @since 0.11 *)
type parent =
  | P_unknown  (** Parent is not specified at this point *)
  | P_none  (** We know the current span has no parent *)
  | P_some of span  (** We know the parent of the current span *)

type user_data =
  [ `Int of int
  | `String of string
  | `Bool of bool
  | `Float of float
  | `None
  ]
(** User defined data, generally passed as key/value pairs to whatever collector
    is installed (if any). *)

type explicit_span = span [@@deprecated "use span"]
type explicit_span_ctx = span [@@deprecated "use span"]

type extension_event = ..
(** An extension event, used to add features that are backend specific or simply
    not envisioned by [trace]. See {!Core_ext} for some builtin extension
    events.
    @since 0.8 *)

type extension_parameter = ..
(** An extension parameter, used to carry information for spans/messages/metrics
    that can be backend-specific or just not envisioned by [trace].
    @since 0.11 *)

type metric = ..
(** A metric, can be of many types. See {!Core_ext} for some builtin metrics.
    @since 0.11 *)
