(** use [thread-local-storage] to store ambient spans.

    This doesn't work with cooperative concurrency (Eio, Lwt, etc) but is fine
    in a threaded context.

    @since 0.12 *)

open Trace_core

val k_span : span Thread_local_storage.t
(** Key to access the current span *)

val provider : Ambient_span_provider.t
(** Provider that uses [Thread_local_storage] to store the current ambient span.
    This works well when concurrency is based on thread, or if there is no
    concurrency. *)

val setup : unit -> unit
(** Install the provider *)
