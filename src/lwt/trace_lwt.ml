(** Optional interface with lwt.

    @since NEXT_RELEASE *)

open Trace_core

let k_ambient_span : span Lwt.key = Lwt.new_key ()

let ambient_span_provider : Trace_core.Ambient_span_provider.t =
  ASP_some
    ( (),
      {
        get_current_span = (fun () -> Lwt.get k_ambient_span);
        with_current_span_set_to =
          (fun () span f ->
            Lwt.with_value k_ambient_span (Some span) (fun () -> f span));
      } )

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
