(** Optional interface with lwt.

    This provides a Lwt-friendly variant of {!Trace_core.with_span}.

    To track the ambient span, which can be useful for some backends or for
    async spans, you can use [Ambient_context_lwt], a collector-specific ambient
    span provider (eg [Opentelemetry_trace] comes with one), or define your own
    like this:

    {[
      (* new key to track the current span in lwt context *)
      let k_ambient_span : Trace_core.span Lwt.key = Lwt.new_key ()

      (* ambient span provider, install it using Trace_core.set_ambient_context_provider] *)
      let ambient_span_provider : Trace_core.Ambient_span_provider.t =
        ASP_some
          ( (),
            {
              get_current_span = (fun () -> Lwt.get k_ambient_span);
              with_current_span_set_to =
                (fun () span f ->
                  Lwt.with_value k_ambient_span (Some span) (fun () -> f span));
            } )
    ]}

    @since NEXT_RELEASE *)

open Trace_core

(** [with_span name f] enters a span [sp], calls [f sp] which returns a Lwt
    promise, and make sure to exit the span [sp] when [f sp] exits (or fails).

    This is similar to {!Trace_core.with_span} but it respects the promise
    semnatics of Lwt (ie. it doesn't exit the span immediately instead of
    waiting for the promise to end).

    To track the current span you still need to install a Lwt-friendly
    {!Trace_core.Ambient_span_provider.t} (probably using {!Lwt.with_value}). *)
let with_span ?level ?__FUNCTION__ ~__FILE__ ~__LINE__ ?parent ?params ?data
    name (f : span -> 'a Lwt.t) : 'a Lwt.t =
  if Trace_core.enabled () then (
    let span =
      Trace_core.enter_span ?level ?__FUNCTION__ ~__FILE__ ~__LINE__ ?parent
        ?params ?data name
    in
    let fut = Trace_core.with_current_span_set_to span f in
    Lwt.on_termination fut (fun () -> Trace_core.exit_span span);
    fut
  ) else
    f Trace_core.Collector.dummy_span
