open Core
open Sexplib.Sexp

open LoopInvGen

let read_grammar_from grammar_file =
  let rules = ref [] and funcs = ref []
  in List.iter (input_sexps (Utils.get_in_channel grammar_file))
               ~f:(function [@warning "-8"]
                   | List ((Atom "grammar") :: rules_list) -> rules := rules_list
                   | List ((Atom "functions") :: funcs_list) -> funcs := funcs_list)
   ; (!rules , !funcs)

let translate_to_general benchmark =
  let parsed = SyGuS.parse_sexps benchmark
  in let pre_vars = List.map ~f:(fun (v,_) -> Atom v) parsed.pre_func.args
  in let inv_vars = List.map ~f:(fun (v,_) -> Atom v) parsed.inv_func.args
  in let primed_inv_vars = List.map ~f:(fun (v,_) -> Atom (v ^ "!")) parsed.inv_func.args
  in let trans_vars = List.map ~f:(fun (v,_) -> Atom v) parsed.trans_func.args
  in let post_vars = List.map ~f:(fun (v,_) -> Atom v) parsed.post_func.args
  in List.rev (
       List.fold benchmark ~init:[]
                 ~f:(fun acc sexp -> match sexp with
                     | List ((Atom "synth-inv") :: y :: z :: r)
                       -> (List ((Atom "synth-fun") :: y :: z :: (Atom "Bool") :: r)) :: acc
                     | List [(Atom "declare-primed-var") ; (Atom vname) ; vtype]
                       -> (List [ (Atom "declare-var") ; (Atom (vname ^ "!")) ; vtype ])
                       :: (List [ (Atom "declare-var") ; (Atom vname) ; vtype ])
                       :: acc
                     | List [(Atom "inv-constraint") ; inv_name ; pre_name ; trans_name ; post_name]
                       -> (List [ (Atom "constraint")
                                ; (List [ (Atom "=>")
                                        ; (List (inv_name :: inv_vars))
                                        ; (List (post_name :: post_vars)) ]) ])
                       :: (List [ (Atom "constraint")
                                ; (List [ (Atom "=>")
                                        ; (List [ (Atom "and")
                                                ; (List (inv_name :: inv_vars))
                                                ; (List (trans_name :: trans_vars)) ])
                                        ; (List (inv_name :: primed_inv_vars)) ]) ])
                       :: (List [ (Atom "constraint")
                                ; (List [ (Atom "=>")
                                        ; (List (pre_name :: pre_vars))
                                        ; (List (inv_name :: inv_vars)) ]) ])
                       :: acc
                     | _ -> sexp :: acc
  ))

let replace grammar_rules ~benchmark do_replace_vars do_replace_consts =
  let parsed = SyGuS.parse_sexps benchmark in
  let found_consts =
        List.dedup_and_sort ~compare:Poly.compare
                            ((Value.Int 0) :: (Value.Int 1)
                            :: (Value.Bool true) :: (Value.Bool false)
                            :: parsed.constants)
  in let found_vars =
       List.find_map_exn benchmark
         ~f:(function
             | List ((Atom "synth-inv") :: _ :: (List z) :: _)
               -> Some (List.dedup_and_sort ~compare:Poly.compare z)
             | _ -> None)
  in let rec helper = function
       | Atom _ as sexp -> [ sexp ]
       | List [ (Atom "Constant") ; (Atom ctype) ] as sexp
         -> if not do_replace_consts then [ sexp ]
            else List.filter_map found_consts
                                 ~f:(fun v -> if Type.to_string (Value.typeof v) = ctype
                                              then Some (Atom (Value.to_string v))
                                              else None)
       | List [ (Atom "Variable") ; vtype ] as sexp
         -> if not do_replace_vars then [ sexp ]
            else List.filter_map found_vars
                                 ~f:(fun [@warning "-8"] (List [v;t])
                                     -> if t = vtype then Some v else None)
       | List sexps -> [ List (List.(concat (map ~f:helper sexps))) ]
  in List.(concat (map ~f:helper grammar_rules))

let fix_arity benchmark =
  let rec helper = function
    | Atom _ as sexp -> sexp
    | List ( ((Atom "and") as op) :: operands )
    | List ( ((Atom "or") as op) :: operands )
    | List ( ((Atom "+") as op) :: operands )
    | List ( ((Atom "*") as op) :: operands )
      -> let operands = List.map ~f:helper operands
          in List.fold (List.tl_exn operands) ~init:(List.hd_exn operands)
                       ~f:(fun acc operand -> List [ op ; operand ; acc ])
    | List sexps -> List (List.map ~f:helper sexps)
  in List.map ~f:helper benchmark

let rec replace_using_table table = function
  | Atom a -> begin match String.Table.find table a with
                | None -> Atom a
                | Some v -> Atom v
              end
  | List l -> List (List.map ~f:(replace_using_table table) l)

let sanitize_names benchmark = function
  | None -> benchmark
  | Some map_file
    -> let open Out_channel in
        let mapch = create map_file in
        let sanitize str = String.tr str ~target:'-' ~replacement:'_' in
        let parsed = SyGuS.parse_sexps benchmark in
        let names_table = String.Table.create () ~size:(List.length parsed.variables)
         in List.iter
              parsed.variables
              ~f:(fun (v,_) -> let sv = sanitize v
                                in output_string mapch ("(" ^ sv ^ " " ^ v ^ ")\n")
                                ; String.Table.set names_table ~key:v ~data:sv)
          ; List.iter
              (parsed.inv_func :: parsed.functions)
              ~f:(fun f -> let sfname = sanitize f.name
                            in output_string mapch ("(" ^ sfname ^ " " ^ f.name ^ ")\n")
                            ; String.Table.set names_table ~key:f.name ~data:sfname)
          ; close mapch
          ; List.map ~f:(replace_using_table names_table) benchmark

let main gramfile do_translate do_replace_vars do_replace_consts do_fix_arity
         sanitize_map_file unsanitize_map_file inputfile () =

  let in_chan = Utils.get_in_channel inputfile in
  let benchmark = ref (input_sexps in_chan)
   in In_channel.close in_chan
    ; begin match unsanitize_map_file with
      | Some umap_file
        -> let umap_chan = In_channel.create umap_file in
           let umap_sexps = input_sexps umap_chan in
           let umap_table = String.Table.create () ~size:(List.length umap_sexps)
            in In_channel.close umap_chan
             ; List.iter umap_sexps
                 ~f:(fun [@warning "-8"] (List [ (Atom sname) ; (Atom name) ])
                     -> String.Table.set umap_table ~key:sname ~data:name)
             ; benchmark := List.map ~f:(replace_using_table umap_table) !benchmark
      | None -> benchmark := sanitize_names !benchmark sanitize_map_file
              ; begin match gramfile with
                | None -> ()
                | Some gfile
                  -> let (rules, funcs) = read_grammar_from gfile in
                      let new_rules = replace rules ~benchmark:!benchmark
                                              do_replace_vars do_replace_consts
                      in benchmark := List.rev (
                           List.fold !benchmark ~init:[]
                             ~f:(fun acc sexp -> match sexp with
                                 | List ((Atom "synth-inv" as x) :: y :: z :: _)
                                   -> (List [x ; y ; z ; (List new_rules)])
                                   :: (funcs @ acc)
                                 | _ -> sexp :: acc))
                end
              ; if do_fix_arity then benchmark := fix_arity !benchmark
              ; if do_translate then benchmark := translate_to_general !benchmark
      end
    ; List.iter !benchmark ~f:(fun s -> Out_channel.print_endline
                                          (Sexp.to_string_hum ~indent:4 s))

let spec =
  let open Command.Spec in (
    empty
    +> flag "-g" (optional string)
       ~doc:"FILENAME The grammar file for the benchmark."
    +> flag "-t" no_arg
       ~doc:"Translate the SyGuS-INV benchmark to a SyGuS-General one."
    +> flag "-r" no_arg
       ~doc:"Replace (Variable T) in the grammar with non-terminals that point to variables."
    +> flag "-c" no_arg
       ~doc:"Replace (Constant T) in the grammar with non-terminals that point to constants."
    +> flag "-a" no_arg
       ~doc:"Replace variadic versions of +, *, and, or with binary versions."
    +> flag "-s" (optional string)
       ~doc:"Sanitize variable and function names and generate a mapping file."
    +> flag "-u" (optional string)
       ~doc:"Unsanitize using a given mapping file."
    +> anon (maybe_with_default "-" ("filename" %: file))
  )

let () =
  Command.run
    (Command.basic_spec spec main
       ~summary: "Apply simple transformations to a SyGuS-INV problem.")
