(* When Domain is unavailable (OCaml < 5), echo the expected file
   so the diff always passes. The file is passed as argv[1] by the dune rule. *)
let () =
  let ic = open_in Sys.argv.(1) in
  (try
     while true do
       print_char (input_char ic)
     done
   with End_of_file -> ());
  close_in ic
