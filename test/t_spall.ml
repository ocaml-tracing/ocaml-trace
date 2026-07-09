module Trace = Trace_core

let () =
  Trace_spall.Private_.mock_all_ ();
  let path = Filename.temp_file "test_spall" ".spall" in
  Fun.protect
    ~finally:(fun () -> try Sys.remove path with _ -> ())
    (fun () ->
      Trace_spall.with_setup ~out:(`File path) () (fun () ->
          Trace.set_process_name "test";
          Trace.set_thread_name "main";
          Trace.with_span ~__FILE__ ~__LINE__ "outer" (fun _sp ->
              Trace.with_span ~__FILE__ ~__LINE__ "inner" (fun _sp -> ())));

      (* verify the binary header *)
      let ic = open_in_bin path in
      Fun.protect
        ~finally:(fun () -> close_in ic)
        (fun () ->
          let read_u64 () =
            let b = Bytes.create 8 in
            really_input ic b 0 8;
            (* little-endian u64 *)
            let r = ref Int64.zero in
            for i = 7 downto 0 do
              r :=
                Int64.add (Int64.shift_left !r 8)
                  (Int64.of_int (Char.code (Bytes.get b i)))
            done;
            !r
          in
          let magic = read_u64 () in
          assert (magic = 0x0BADF00DL);
          let version = read_u64 () in
          assert (version = 3L);
          Printf.printf "magic=0x%LX version=%Ld OK\n" magic version))
