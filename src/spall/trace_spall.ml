open Trace_core
module Collector_spall = Collector_spall
module Writer = Writer

type output =
  [ `Stdout
  | `Stderr
  | `File of string
  ]

let collector ~(out : [< output ]) () : collector =
  let oc, close_oc =
    match out with
    | `Stdout -> stdout, false
    | `Stderr -> stderr, false
    | `File path -> open_out path, true
  in
  let pid = Trace_util.Mock_.get_pid () in
  let st = Collector_spall.create ~pid ~oc ~close_oc () in
  Collector_spall.collector st

open struct
  let register_atexit =
    let has_registered = ref false in
    fun () ->
      if not !has_registered then (
        has_registered := true;
        at_exit Trace_core.shutdown
      )
end

let setup ?(out = `Env) () =
  register_atexit ();
  let make_col out = Trace_core.setup_collector (collector ~out ()) in
  match out with
  | `Stderr -> make_col `Stderr
  | `Stdout -> make_col `Stdout
  | `File path -> make_col (`File path)
  | `Env ->
    (match Sys.getenv_opt "TRACE" with
    | Some ("1" | "true") -> make_col (`File "trace.spall")
    | Some "stdout" -> make_col `Stdout
    | Some "stderr" -> make_col `Stderr
    | Some path -> make_col (`File path)
    | None -> ())

let with_setup ?out () f =
  setup ?out ();
  Fun.protect ~finally:Trace_core.shutdown f

module Private_ = struct
  let mock_all_ () = Trace_util.Mock_.mock_all ()
end
