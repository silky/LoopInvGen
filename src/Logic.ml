open Core_kernel

type t = {
  name : string ;
  components : Expr.component list ;
  conflict_group_size_multiplier : int
}

let all_supported =
  let table = String.Table.create () ~size:2
   in List.iter ~f:(fun component -> String.Table.set table ~key:component.name ~data:component)
        [{
           name = "LIA" ;
           components = Th_LIA.components @ Th_Bool.components ;
           conflict_group_size_multiplier = 1
         } ; {
           name = "NIA" ;
           components = (List.hd_exn Th_LIA.components)
                     :: (List.hd_exn Th_NIA.components)
                     :: ( (List.tl_exn Th_LIA.components)
                        @ (List.tl_exn Th_NIA.components)
                        @ Th_Bool.components);
           conflict_group_size_multiplier = 2
         }]
    ; table

let of_string name = String.Table.find_exn all_supported name
