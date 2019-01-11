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
  let all_ctypes = ref [] and all_vtypes = ref []
  in let vars_types =
       List.fold benchmark ~init:[]
         ~f:(fun acc sexp -> match sexp with
             | List ((Atom "synth-inv") :: _ :: (List z) :: _) -> z
             | _ -> acc)
  in let found_vtypes =
       List.dedup_and_sort ~compare:Sexp.compare
                           (List.map vars_types ~f:(fun [@warning "-8"] (List [_;t]) -> t))
  in let rec helper = function
       | Atom _ as sexp -> Some sexp
       | List [ (Atom "Constant") ; (Atom ctype) ] as sexp
         -> Some (if not do_replace_consts then sexp
                  else ( all_ctypes := ctype :: !all_ctypes
                       ; Atom ("ConstantsOfType" ^ ctype) ))
       | List [ (Atom "Variable") ; (Atom vtype) ] as sexp
         -> if not do_replace_vars then Some sexp
            else if List.mem found_vtypes (Atom vtype) ~equal:Sexp.equal
                 then ( all_vtypes := vtype :: !all_vtypes
                      ; Some (Atom ("VariablesOfType" ^ vtype)) )
                 else None
       | List sexps -> Some (List (List.filter_map ~f:helper sexps))
   in let modified_rules = List.filter_map ~f:helper grammar_rules
   in let ctype_rules =
        if not do_replace_consts then []
        else begin
          let parsed = SyGuS.parse_sexps benchmark
           in let found_consts =
                List.dedup_and_sort ~compare:Poly.compare
                   ((Value.Int 0) :: (Value.Int 1) ::
                    (Value.Bool true) :: (Value.Bool false) :: parsed.constants)
          in List.map !all_ctypes
               ~f:(fun ctype
                     -> List [ (Atom ("ConstantsOfType" ^ ctype))
                             ; (Atom ctype)
                             ; (List (List.filter_map found_consts
                                        ~f:(fun value -> if Type.to_string (Value.typeof value) = ctype
                                                         then Some (Atom (Value.to_string value)) else None))) ])
        end
   in let vtype_rules =
        if not do_replace_vars then []
        else begin
          List.map !all_vtypes
            ~f:(fun vtype -> List [ (Atom ("VariablesOfType" ^ vtype))
                                  ; (Atom vtype)
                                  ; (List (List.filter_map vars_types
                                             ~f:(fun [@warning "-8"] (List [v;t])
                                                 -> if t = Atom vtype then Some v else None))) ])
        end
   in List (vtype_rules @ ctype_rules @ modified_rules)

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

let main gramfile do_translate
         do_replace_vars do_replace_consts do_fix_arity
         do_sanitize_names
         sygusfile () =
  let (rules, funcs) = read_grammar_from gramfile in
  let in_chan = Utils.get_in_channel sygusfile in
  let benchmark = input_sexps in_chan in
  let new_rules = replace rules ~benchmark do_replace_vars do_replace_consts in
  let benchmark = List.rev (
                    List.fold benchmark ~init:[]
                      ~f:(fun acc sexp -> match sexp with
                          | List ((Atom "synth-inv" as x) :: y :: z :: _)
                            -> (List [x ; y ; z ; new_rules]) :: (funcs @ acc)
                          | _ -> sexp :: acc))
   in let benchmark = if do_fix_arity then fix_arity benchmark else benchmark
   in let benchmark = if do_translate then translate_to_general benchmark else benchmark
   in List.iter ~f:(fun s -> Stdio.Out_channel.print_endline (Sexp.to_string_hum ~indent:4 s)) benchmark
    ; Stdio.In_channel.close in_chan

let spec =
  let open Command.Spec in (
    empty
    +> flag "-g" (required string)
       ~doc:"FILENAME The grammar file for the benchmark."
    +> flag "-t" no_arg
       ~doc:"Translate the SyGuS-INV benchmark to a SyGuS-General one."
    +> flag "-r" no_arg
       ~doc:"Replace (Variable T) in the grammar with non-terminals that point to variables."
    +> flag "-c" no_arg
       ~doc:"Replace (Constant T) in the grammar with non-terminals that point to constants."
    +> flag "-a" no_arg
       ~doc:"Replace variadic versions of *, *, and, or with binary versions."
    +> flag "-s" no_arg
       ~doc:"Sanitize variable and function names."
    +> anon (maybe_with_default "-" ("filename" %: file))
  )

let () =
  Command.run
    (Command.basic_spec spec main
       ~summary: "Apply simple transformations to a SyGuS-INV problem.")
