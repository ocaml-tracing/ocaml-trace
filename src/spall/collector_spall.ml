open struct
  module TLS = Thread_local_storage
  module A = Trace_core.Internal_.Atomic_

  let with_lock mu f =
    Mutex.lock mu;
    match f () with
    | v ->
      Mutex.unlock mu;
      v
    | exception e ->
      let bt = Printexc.get_raw_backtrace () in
      Mutex.unlock mu;
      Printexc.raise_with_backtrace e bt

  let ( let@ ) = ( @@ )
end

open Trace_core

type span += Span_spall

type thread_state = {
  tid: int;
  pid: int;
  mutable first_ts: int64;
  buf: Buffer.t;
  mutable prev: thread_state;
  mutable next: thread_state;
}

type t = {
  active: bool A.t;
  pid: int;
  mu: Mutex.t;  (** guards: [oc] writes, [all_states] updates *)
  all_states: thread_state Lazy.t;
      (** double linked list. first item is always the main thread. *)
  oc: out_channel;
  close_oc: bool;
  high_water_mark: int;
}

(* One module-level TLS slot shared across all instances; stores a (collector,
   thread_state) pair so we detect stale entries from a previous collector. *)
let tls_key : (t * thread_state) TLS.t = TLS.create ()

let flush_thread_ (self : t) (ts : thread_state) : unit =
  let size = Buffer.length ts.buf in
  if size > 0 then (
    let hdr =
      Writer.write_header ~size ~tid:ts.tid ~pid:ts.pid ~first_ts:ts.first_ts
    in
    output_string self.oc hdr;
    Buffer.output_buffer self.oc ts.buf;
    (* if we overallocated by a lot, free memory *)
    Buffer.reset ts.buf;
    ts.first_ts <- 0L
  )

open struct
  let buf_size = 4_096
  let default_high_water_mark = buf_size
end

let create_thread_state_ (self : t) : thread_state =
  let tid = Trace_util.Mock_.get_tid () in
  let buf = Buffer.create buf_size in
  let rec ts =
    { tid; pid = self.pid; first_ts = 0L; buf; prev = ts; next = ts }
  in
  TLS.set tls_key (self, ts);
  ts

(* Returns the thread_state for this thread+collector, creating it on first
   call. Fast path (after initialization) is lock-free. *)
let get_or_create_thread_ (self : t) : thread_state =
  match TLS.get_opt tls_key with
  | Some (c, ts) when c == self -> ts
  | _ ->
    let ts = create_thread_state_ self in
    with_lock self.mu (fun () ->
        let (lazy start) = self.all_states in
        ts.prev <- start.prev;
        ts.next <- start;
        start.prev.next <- ts;
        start.prev <- ts);
    ts

let flush_all_ self =
  let (lazy start) = self.all_states in
  let cur = ref start in
  let continue = ref true in
  while !continue do
    flush_thread_ self !cur;
    cur := !cur.next;
    if !cur == start then continue := false
  done

let close (self : t) : unit =
  if A.exchange self.active false then (
    let@ () = with_lock self.mu in
    flush_all_ self;
    flush self.oc;
    if self.close_oc then close_out_noerr self.oc
  )

let create ~pid ~oc ?(close_oc = true)
    ?(high_water_mark = default_high_water_mark) () : t =
  let rec self =
    {
      active = A.make true;
      pid;
      mu = Mutex.create ();
      all_states = lazy (create_thread_state_ self);
      oc;
      close_oc;
      high_water_mark;
    }
  in
  ignore (Lazy.force self.all_states : thread_state);
  let hdr = Buffer.create 32 in
  Writer.write_file_header hdr ~timestamp_unit:1e-3;
  Buffer.output_buffer oc hdr;
  flush oc;
  self

open struct
  type st = t

  let init _ = ()
  let shutdown (self : st) = close self

  let enter_span (self : st) ~__FUNCTION__:_ ~__FILE__:_ ~__LINE__:_ ~level:_
      ~params:_ ~data:_ ~parent:_ name : span =
    let ts = Trace_util.Mock_.now_ns () in
    let tst = get_or_create_thread_ self in
    if Buffer.length tst.buf = 0 then tst.first_ts <- ts;
    Writer.write_begin tst.buf ~ts ~name;
    (if Buffer.length tst.buf >= self.high_water_mark then
       let@ () = with_lock self.mu in
       flush_thread_ self tst);
    Span_spall

  let exit_span (self : st) sp =
    match sp with
    | Span_spall ->
      let ts = Trace_util.Mock_.now_ns () in
      let tst = get_or_create_thread_ self in
      Writer.write_end tst.buf ~ts;
      if Buffer.length tst.buf >= self.high_water_mark then
        let@ () = with_lock self.mu in
        flush_thread_ self tst
    | _ -> ()

  let add_data_to_span _st _sp _data = ()
  let message _self ~level:_ ~params:_ ~data:_ ~span:_ _msg = ()
  let metric _self ~level:_ ~params:_ ~data:_ _name _m = ()

  let extension (self : st) ~level:_ ev =
    match ev with
    | Core_ext.Extension_set_thread_name name ->
      let tst = get_or_create_thread_ self in
      let@ () = with_lock self.mu in
      Writer.write_name tst.buf ~kind:`Thread ~name
    | Core_ext.Extension_set_process_name name ->
      let tst = get_or_create_thread_ self in
      let@ () = with_lock self.mu in
      Writer.write_name tst.buf ~kind:`Process ~name
    | _ -> ()
end

let callbacks : _ Collector.Callbacks.t =
  Collector.Callbacks.make ~init ~shutdown ~enter_span ~exit_span
    ~add_data_to_span ~message ~metric ~extension ()

let collector (self : t) : Collector.t = Collector.C_some (self, callbacks)
