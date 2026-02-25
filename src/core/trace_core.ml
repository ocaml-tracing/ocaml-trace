include Types
module A = Atomic_
module Collector = Collector
module Level = Level
module Core_ext = Core_ext

type collector = Collector.t

(* ## globals ## *)

(** Global collector. *)
let collector : collector A.t = A.make Collector.C_none

(* default level for spans without a level *)
let default_level_ = A.make Level.Trace
let current_level_ = A.make Level.Trace

(** Global provider of span context *)
let ambient_span_provider : Ambient_span_provider.t A.t =
  A.make Ambient_span_provider.ASP_none

(* ## implementation ## *)

let[@inline] option_or_ a f =
  match a with
  | Some _ -> a
  | None -> f ()

let data_empty_build_ () = []
let[@inline] enabled () = Collector.is_some (A.get collector)
let[@inline] get_default_level () = A.get default_level_
let[@inline] set_default_level l = A.set default_level_ l
let[@inline] set_current_level l = A.set current_level_ l
let[@inline] get_current_level () = A.get current_level_

let[@inline] check_level_ ~level st (cbs : _ Collector.Callbacks.t) : bool =
  Level.leq level (A.get current_level_) && cbs.enabled st level

let[@inline] current_span () =
  match A.get ambient_span_provider with
  | ASP_none -> None
  | ASP_some (st, cbs) -> cbs.get_current_span st

let[@inline] with_current_span_set_to sp f =
  match A.get ambient_span_provider with
  | ASP_none -> f sp
  | ASP_some (st, cbs) -> cbs.with_current_span_set_to st sp f

let parent_of_span_opt_opt = function
  | None ->
    (match current_span () with
    | None -> P_unknown
    | Some p -> P_some p)
  | Some None -> P_none
  | Some (Some p) -> P_some p

let enter_span_st st (cbs : _ Collector.Callbacks.t) ?__FUNCTION__ ~__FILE__
    ~__LINE__ ~level ?parent ?(params = []) ?(data = data_empty_build_) name :
    span =
  let parent = parent_of_span_opt_opt parent in
  let data = data () in
  cbs.enter_span st ~__FUNCTION__ ~__FILE__ ~__LINE__ ~level ~parent ~params
    ~data name

let with_span_collector_ st (cbs : _ Collector.Callbacks.t) ?__FUNCTION__
    ~__FILE__ ~__LINE__ ~level ?parent ?params ?data name f =
  let sp : span =
    enter_span_st st cbs ?__FUNCTION__ ~__FILE__ ~__LINE__ ~level ?parent
      ?params ?data name
  in
  match
    (* set [sp] as current span before calling [f sp] *)
    with_current_span_set_to sp f
  with
  | res ->
    cbs.exit_span st sp;
    res
  | exception exn ->
    let bt = Printexc.get_raw_backtrace () in
    cbs.exit_span st sp;
    Printexc.raise_with_backtrace exn bt

let[@inline] with_span ?(level = A.get default_level_) ?__FUNCTION__ ~__FILE__
    ~__LINE__ ?parent ?params ?data name f =
  match A.get collector with
  | C_some (st, cbs) when check_level_ ~level st cbs ->
    with_span_collector_ st cbs ?__FUNCTION__ ~__FILE__ ~__LINE__ ~level ?parent
      ?params ?data name f
  | _ ->
    (* fast path: no collector, no span *)
    f Collector.dummy_span

let[@inline] enter_span ?(level = A.get default_level_) ?__FUNCTION__ ~__FILE__
    ~__LINE__ ?flavor ?parent ?(params = []) ?data name : span =
  match A.get collector with
  | C_some (st, cbs) when check_level_ ~level st cbs ->
    let params =
      match flavor with
      | None -> params
      | Some f -> Core_ext.Extension_span_flavor f :: params
    in
    (enter_span_st [@inlined never]) st cbs ?__FUNCTION__ ~__FILE__ ~__LINE__
      ~level ?parent ~params ?data name
  | _ -> Collector.dummy_span

let[@inline] exit_span sp : unit =
  match A.get collector with
  | C_none -> ()
  | C_some (st, cbs) -> cbs.exit_span st sp

let[@inline] add_data_to_span sp data : unit =
  if sp != Collector.dummy_span && data <> [] then (
    match A.get collector with
    | C_none -> ()
    | C_some (st, cbs) -> cbs.add_data_to_span st sp data
  )

let message_collector_ st (cbs : _ Collector.Callbacks.t) ~level ?span
    ?(params = []) ?(data = data_empty_build_) msg : unit =
  let data = data () in
  let span = option_or_ span current_span in
  cbs.message st ~level ~span ~params ~data msg

let[@inline] message ?(level = A.get default_level_) ?span ?params ?data msg :
    unit =
  match A.get collector with
  | C_some (st, cbs) when check_level_ ~level st cbs ->
    (message_collector_ [@inlined never]) st cbs ~level ?span ?params ?data msg
  | _ -> ()

let messagef ?(level = A.get default_level_) ?span ?params ?data k =
  match A.get collector with
  | C_some (st, cbs) when check_level_ ~level st cbs ->
    k (fun fmt ->
        Format.kasprintf
          (fun str -> message_collector_ st cbs ~level ?span ?params ?data str)
          fmt)
  | _ -> ()

let metric ?(level = A.get default_level_) ?(params = [])
    ?(data = data_empty_build_) name m : unit =
  match A.get collector with
  | C_some (st, cbs) when check_level_ ~level st cbs ->
    let data = data () in
    cbs.metric st ~level ~params ~data name m
  | _ -> ()

let counter_int ?level ?params ?data name n : unit =
  metric ?level ?params ?data name (Core_ext.Metric_int n)

let counter_float ?level ?params ?data name n : unit =
  metric ?level ?params ?data name (Core_ext.Metric_float n)

let setup_collector c : unit =
  while
    let cur = A.get collector in
    match cur with
    | C_some _ -> invalid_arg "trace: collector already present"
    | C_none -> not (A.compare_and_set collector cur c)
  do
    ()
  done;

  (* initialize collector *)
  match c with
  | C_none -> ()
  | C_some (st, cb) -> cb.init st

let shutdown () =
  match A.exchange collector C_none with
  | C_none -> ()
  | C_some (st, cbs) -> cbs.shutdown st

let with_setup_collector c f =
  setup_collector c;
  Fun.protect ~finally:shutdown f

type extension_event = Types.extension_event = ..

let[@inline] extension_event ?(level = A.get default_level_) ev : unit =
  match A.get collector with
  | C_some (st, cbs) when check_level_ ~level st cbs ->
    cbs.extension st ~level ev
  | _ -> ()

let set_thread_name name : unit =
  extension_event @@ Core_ext.Extension_set_thread_name name

let set_process_name name : unit =
  extension_event @@ Core_ext.Extension_set_process_name name

module Internal_ = struct
  module Atomic_ = Atomic_
end

(* ### deprecated *)

[@@@ocaml.alert "-deprecated"]

let enter_manual_span ~parent ?flavor ?level ?__FUNCTION__ ~__FILE__ ~__LINE__
    ?data name : explicit_span =
  let params =
    match flavor with
    | None -> []
    | Some f -> [ Core_ext.Extension_span_flavor f ]
  in
  enter_span ~parent ~params ?level ?__FUNCTION__ ~__FILE__ ~__LINE__ ?data name

let enter_manual_toplevel_span ?flavor ?level ?__FUNCTION__ ~__FILE__ ~__LINE__
    ?data name : explicit_span =
  enter_manual_span ~parent:None ?flavor ?level ?__FUNCTION__ ~__FILE__
    ~__LINE__ ?data name

let enter_manual_sub_span ~parent ?flavor ?level ?__FUNCTION__ ~__FILE__
    ~__LINE__ ?data name : explicit_span =
  enter_manual_span ~parent:(Some parent) ?flavor ?level ?__FUNCTION__ ~__FILE__
    ~__LINE__ ?data name

let exit_manual_span = exit_span
let add_data_to_manual_span = add_data_to_span

[@@@ocaml.alert "+deprecated"]
