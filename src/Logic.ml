open Core_kernel

type t = {
  name : string ;
  components_per_level : Expr.component list array ;
  conflict_group_size_multiplier : int
}

let all_supported =
   let table = String.Table.create () ~size:2
   in List.iter ~f:(fun component -> String.Table.set table ~key:component.name ~data:component)
        [{
           name = "LIA" ;
           components_per_level = [|
             (BooleanComponents.all @ IntegerComponents.relational) ;
             (BooleanComponents.all @ IntegerComponents.presburger) ;
             (BooleanComponents.all @ IntegerComponents.all_linear) ;
           |] ;
           conflict_group_size_multiplier = 1
         } ; {
           name = "NIA" ;
           components_per_level = [|
             (BooleanComponents.all @ IntegerComponents.relational) ;
             (BooleanComponents.all @ IntegerComponents.presburger) ;
             (BooleanComponents.all @ IntegerComponents.all_linear) ;
             (BooleanComponents.all @ IntegerComponents.peano) ;
             (BooleanComponents.all @ IntegerComponents.all_non_linear) ;
           |] ;
           conflict_group_size_multiplier = 2
         }]
    ; table

let of_string name = String.Table.find_exn all_supported name
