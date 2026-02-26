(** use [thread-local-storage] to store ambient spans.

    This doesn't work with cooperative concurrency (Eio, Lwt, etc) but is fine
    in a threaded context. *)

open Trace_core

val k_span : span Thread_local_storage.t
(** Key to access the current span *)

val provider : Ambient_span_provider.t

val setup : unit -> unit
(** Install the provider *)
