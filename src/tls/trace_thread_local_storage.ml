open Trace_core

let k_span : span Thread_local_storage.t = Thread_local_storage.create ()

open struct
  let get_current_span () = Thread_local_storage.get_opt k_span

  let with_current_span_set_to () span f =
    let prev_span =
      try Thread_local_storage.get_exn k_span
      with Thread_local_storage.Not_set -> Collector.dummy_span
    in
    Thread_local_storage.set k_span span;

    match f span with
    | res ->
      Thread_local_storage.set k_span prev_span;
      res
    | exception exn ->
      let bt = Printexc.get_raw_backtrace () in
      Thread_local_storage.set k_span prev_span;
      Printexc.raise_with_backtrace exn bt

  let callbacks : unit Ambient_span_provider.Callbacks.t =
    { get_current_span; with_current_span_set_to }
end

let provider : Ambient_span_provider.t = ASP_some ((), callbacks)
let setup () = Trace_core.set_ambient_context_provider provider
