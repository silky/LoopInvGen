open Core_kernel

open SyGuS
open Utils
open VPIE

type 'a config = {
  for_VPIE : 'a VPIE.config ;

  base_random_seed : string ;
  max_restarts : int ;
  max_steps_on_restart : int ;
  model_completion_mode : [ `RandomGeneration | `UsingZ3 ] ;
}

let default_config = {
  for_VPIE = {
    VPIE.default_config with simplify = false ;
  } ;

  base_random_seed = "LoopInvGen" ;
  max_restarts = 64 ;
  max_steps_on_restart = 256 ;
  model_completion_mode = `RandomGeneration ;
}

let learnInvariant_internal ?(conf = default_config) (sygus : SyGuS.t)
                            ~(states : Value.t list list) (z3 : ZProc.t)
                            (seed_string : string): Job.desc =
  let invf_call =
      "(invf " ^ (List.to_string_map sygus.inv_func.args ~sep:" " ~f:fst) ^ ")" in
  let invf'_call =
    "(invf " ^ (List.to_string_map sygus.inv_func.args ~sep:" "
                  ~f:(fun (s, _) -> s ^ "!")) ^ ")" in
  let eval_term = (if not (conf.model_completion_mode = `UsingZ3) then "true"
                   else "(and " ^ invf_call ^ " " ^ sygus.trans_func.expr ^ ")") in
  let rec helper good_states bad_states =
    Log.debug (lazy ("Invoking synthesizer with "
                      ^ (conf.for_VPIE.for_PIE.synth_logic.name) ^ " logic."
                      ^ (Log.indented_sep 0) ^ "Conflict group ("
                      ^ (List.to_string_map sygus.synth_variables ~sep:" , "
                           ~f:(fun (v,t) -> v ^ " :" ^ (Type.to_string t))) ^ "):" ^ (Log.indented_sep 2)
          ^ "POS (" ^ (Int.to_string (List.length good_states)) ^ "):" ^ (Log.indented_sep 4)
                      ^ (List.to_string_map good_states ~sep:(Log.indented_sep 4)
                           ~f:(fun vl -> "(" ^ (List.to_string_map vl ~f:Value.to_string ~sep:" , ") ^ ")")) ^ (Log.indented_sep 2)
          ^ "NEG (" ^ (Int.to_string (List.length bad_states)) ^ "):" ^ (Log.indented_sep 4)
                      ^ (List.to_string_map bad_states ~sep:(Log.indented_sep 4)
                           ~f:(fun vl -> "(" ^ (List.to_string_map vl ~f:Value.to_string ~sep:" , ") ^ ")")))) ;
    let open Synthesizer in
    let result = solve sygus.constants {
      logic = conf.for_VPIE.for_PIE.synth_logic ;
      arg_names = List.map sygus.synth_variables ~f:fst ;
      inputs = (
        let all_inputs = good_states @ bad_states
         in List.mapi sygus.synth_variables
                      ~f:(fun i _ -> Array.of_list List.(
                                       map all_inputs ~f:(fun l -> nth_exn l i)))) ;
      outputs = Array.of_list ( (List.map good_states ~f:(fun _ -> Value.Bool true))
                              @ (List.map bad_states ~f:(fun _ -> Value.Bool false)))
    } in
    let candidate = if result.constraints = [] then result.string
                    else ( "(and " ^ result.string
                         ^ (String.concat ~sep:" " result.constraints)
                         ^ ")")
     in (Stats.add_candidate ())
      ; if candidate = "false" then "false" else
     let open ZProc in
     let open Quickcheck in
     let inv_def = "(define-fun invf ("
                 ^ (List.to_string_map sygus.inv_func.args ~sep:" "
                                       ~f:(fun (s, t) -> "(" ^ s ^ " " ^ (Type.to_string t) ^ ")"))
                 ^ ") Bool " ^ candidate ^ ")"
      in Log.info (lazy ("GUESS >> Candidate invariant:"
                   ^ (Log.indented_sep 4) ^ candidate))
       ; match implication_counter_example z3 candidate sygus.post_func.expr with
          | Some ce
            -> let [@warning "-8"] Some state =
                  random_value ~seed:(`Deterministic seed_string)
                                (Simulator.gen_state_from_model sygus (Some ce))
                in helper good_states (state :: bad_states)
          | None -> begin match implication_counter_example z3 sygus.post_func.expr candidate with
                      | Some ce
                        -> let [@warning "-8"] Some state =
                              random_value ~seed:(`Deterministic seed_string)
                                            (Simulator.gen_state_from_model sygus (Some ce))
                            in helper (state :: good_states) bad_states
                      | None -> ZProc.create_scope z3 ~db:[ inv_def ; "(assert " ^ sygus.trans_func.expr ^ ")" ]
                              ; let ind_ce = implication_counter_example ~eval_term z3 invf_call invf'_call
                                in close_scope z3
                                  ; begin match ind_ce with
                                      | Some ce
                                        -> let [@warning "-8"] Some state =
                                              random_value ~seed:(`Deterministic seed_string)
                                                            Simulator.(gen_state_from_model sygus (Some (filter_state ~trans:true ce)))
                                            in helper (state :: good_states) bad_states
                                      | None -> candidate
                                    end
                    end
   in helper states []

let learnInvariant ?(conf = default_config) ~(states : Value.t list list)
                   ~(zpath : string) (sygus : SyGuS.t) : Job.desc =
  let open ZProc
  in process ~zpath
       ~random_seed:(Some (Int.to_string (Quickcheck.(random_value ~seed:(`Deterministic conf.base_random_seed)
                                                                   (Generator.small_non_negative_int)))))
       (fun z3 -> Simulator.setup sygus z3
                ; if not ((implication_counter_example z3 sygus.pre_func.expr sygus.post_func.expr) = None) then "false"
                  else learnInvariant_internal ~conf ~states sygus z3 conf.base_random_seed)
