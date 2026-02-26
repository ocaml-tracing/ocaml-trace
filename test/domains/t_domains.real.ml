(* Test concurrent span recording across multiple domains (OCaml 5+).
   Each domain runs [iters] spans.  We embed the recording thread's id into
   the span value so that exit events can be attributed to the right domain,
   then verify that every domain has exactly [iters] enters and exits. *)

let ( let@ ) = ( @@ )
let iters = 10_000

(* Custom span type that carries the thread id of the recording domain. *)
type Trace_core.span += Thread_span of int

let make_recorder () =
  let log = Queue.create () in
  let mu = Mutex.create () in
  let add x =
    Mutex.lock mu;
    Queue.add x log;
    Mutex.unlock mu
  in
  let enter_span () ~__FUNCTION__:_ ~__FILE__:_ ~__LINE__:_ ~level:_ ~params:_
      ~data:_ ~parent:_ _name =
    let tid = Thread.id (Thread.self ()) in
    add (`Enter tid);
    Thread_span tid
  in
  let exit_span () sp =
    match sp with
    | Thread_span tid -> add (`Exit tid)
    | _ -> ()
  in
  let message () ~level:_ ~params:_ ~data:_ ~span:_ _msg =
    add (`Msg (Thread.id (Thread.self ())))
  in
  let metric () ~level:_ ~params:_ ~data:_ _name _m = () in
  let add_data_to_span () _sp _data = () in
  let coll =
    Trace_core.Collector.(
      C_some
        ( (),
          Callbacks.make ~enter_span ~exit_span ~add_data_to_span ~message
            ~metric () ))
  in
  coll, fun () -> Queue.fold (fun acc x -> x :: acc) [] log |> List.rev

let () =
  print_endline "=== domain concurrency ===";
  let coll, get = make_recorder () in
  let@ () = Trace_core.with_setup_collector coll in
  let n = 4 in
  (* Each domain returns its own thread id so we can check per-domain counts. *)
  let domains =
    Array.init n (fun _i ->
        Domain.spawn (fun () ->
            let tid = Thread.id (Thread.self ()) in
            for j = 1 to iters do
              Trace_core.with_span ~__FILE__ ~__LINE__ "" @@ fun _ ->
              Trace_core.message "";
              if j mod 1000 = 0 then Thread.yield ()
            done;
            tid))
  in
  let tids = Array.map Domain.join domains in
  let events = get () in
  let count pred = List.length (List.filter pred events) in
  (* For each domain, verify exactly [iters] enters and [iters] exits. *)
  Array.iteri
    (fun i tid ->
      let n_enter =
        count (function
          | `Enter t -> t = tid
          | _ -> false)
      in
      let n_exit =
        count (function
          | `Exit t -> t = tid
          | _ -> false)
      in
      let n_msg =
        count (function
          | `Msg t -> t = tid
          | _ -> false)
      in
      Printf.printf "domain-%d: enter=%d exit=%d msg=%d%s\n" i n_enter n_exit
        n_msg
        (if n_enter = iters && n_exit = iters && n_msg = iters then
           ""
         else
           " FAIL"))
    tids
