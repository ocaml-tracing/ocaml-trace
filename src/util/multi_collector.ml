open Trace_core

open struct
  type st = Collector.t array
  type span += Span_combine of span array

  let init st =
    for i = 0 to Array.length st - 1 do
      let (Collector.C_some (st, cb)) = Array.get st i in
      cb.init st
    done
    [@ocaml.warning "-8"]

  let shutdown st =
    for i = 0 to Array.length st - 1 do
      let (Collector.C_some (st, cb)) = Array.get st i in
      cb.shutdown st
    done
    [@ocaml.warning "-8"]

  let enter_span st ~__FUNCTION__ ~__FILE__ ~__LINE__ ~level ~params ~data
      ~parent name : span =
    let spans =
      Array.map
        (fun[@ocaml.warning "-8"] coll ->
          let (Collector.C_some (st, cb)) = coll in
          cb.enter_span st ~__FUNCTION__ ~__FILE__ ~__LINE__ ~level ~params
            ~data ~parent name)
        st
    in
    Span_combine spans

  let exit_span st span =
    match span with
    | Span_combine spans ->
      assert (Array.length spans = Array.length st);
      for i = 0 to Array.length st - 1 do
        let (Collector.C_some (st, cb)) = Array.get st i in
        cb.exit_span st spans.(i)
      done
      [@ocaml.warning "-8"]
    | _ -> ()

  let add_data_to_span st span data =
    match span with
    | Span_combine spans when data <> [] ->
      assert (Array.length spans = Array.length st);
      for i = 0 to Array.length st - 1 do
        let (Collector.C_some (st, cb)) = Array.get st i in
        cb.add_data_to_span st spans.(i) data
      done
      [@ocaml.warning "-8"]
    | _ -> ()

  let message st ~level ~params ~data ~span msg =
    for i = 0 to Array.length st - 1 do
      let (Collector.C_some (st, cb)) = Array.get st i in
      cb.message st ~level ~span ~params ~data msg
    done
    [@ocaml.warning "-8"]

  let metric st ~level ~params ~data name m =
    for i = 0 to Array.length st - 1 do
      let (Collector.C_some (st, cb)) = Array.get st i in
      cb.metric st ~level ~params ~data name m
    done
    [@ocaml.warning "-8"]

  let extension st ~level ev : unit =
    for i = 0 to Array.length st - 1 do
      let (Collector.C_some (st, cb)) = Array.get st i in
      cb.extension st ~level ev
    done
    [@ocaml.warning "-8"]

  let enabled st level : bool =
    Array.exists
      (fun (Collector.C_some (st, cb)) -> cb.enabled st level)
      st [@ocaml.warning "-8"]

  let combine_cb : st Collector.Callbacks.t =
    {
      Collector.Callbacks.init;
      enter_span;
      exit_span;
      enabled;
      message;
      add_data_to_span;
      metric;
      extension;
      shutdown;
    }
end

let combine_l (cs : Collector.t list) : Collector.t =
  let cs =
    List.filter
      (function
        | Collector.C_none -> false
        | Collector.C_some _ -> true)
      cs
  in
  match cs with
  | [] -> C_none
  | [ c ] -> c
  | _ -> C_some (Array.of_list cs, combine_cb)

let combine (s1 : Collector.t) (s2 : Collector.t) : Collector.t =
  combine_l [ s1; s2 ]
