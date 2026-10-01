open struct
  let[@inline] add_u8 buf n = Buffer.add_char buf (Char.chr (n land 0xff))
  let add_u64_le = Buffer.add_int64_le
  let[@inline] add_f64_le buf f = add_u64_le buf (Int64.bits_of_float f)
end

let write_file_header buf ~timestamp_unit =
  add_u64_le buf 0x0BADF00DL;
  add_u64_le buf 3L;
  add_f64_le buf timestamp_unit;
  add_u64_le buf 0L

let write_header ~size ~tid ~pid ~first_ts : string =
  let buf = Bytes.create 20 in
  Bytes.set_int32_le buf 0 (Int32.of_int size);
  Bytes.set_int32_le buf 4 (Int32.of_int tid);
  Bytes.set_int32_le buf 8 (Int32.of_int pid);
  Bytes.set_int64_le buf 12 first_ts;
  Bytes.unsafe_to_string buf

(* type=3 Begin: type(u8) when(u64) name_len(u8) args_len(u8) name_bytes *)
let write_begin buf ~ts ~name =
  let name_len = min (String.length name) 255 in
  add_u8 buf 3;
  add_u64_le buf ts;
  add_u8 buf name_len;
  add_u8 buf 0;
  Buffer.add_substring buf name 0 name_len

(* type=4 End: type(u8) when(u64) *)
let write_end buf ~ts =
  add_u8 buf 4;
  add_u64_le buf ts

(* type=8 NameProcess / type=9 NameThread: type(u8) name_len(u8) name_bytes *)
let write_name buf ~kind ~name =
  let ty =
    match kind with
    | `Process -> 8
    | `Thread -> 9
  in
  let name_len = min (String.length name) 255 in
  add_u8 buf ty;
  add_u8 buf name_len;
  Buffer.add_substring buf name 0 name_len
