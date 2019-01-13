(grammar
  (Start Bool (BoolExpr))
  (BoolExpr Bool (
	  true false
	  (Variable Bool)
	  (not BoolExpr)
	  (or BoolExpr BoolExpr)
	  (and BoolExpr BoolExpr)
	  (= IntExpr IntExpr)
	  (> IntExpr IntExpr)
	  (< IntExpr IntExpr)
	  (>= IntExpr IntExpr)
	  (<= IntExpr IntExpr)
  ))
  (IntExpr Int (
	  (Constant Int)
	  (Variable Int)
	  (+ IntExpr IntExpr)
	  (- IntExpr IntExpr)
	  (* IntExpr IntExpr)
	  (div IntExpr IntExpr)
	  (mod IntExpr IntExpr)
  ))
)
(functions
  (define-fun modfn ((x Int) (y Int)) Int (- x (* y (div x y))))
)
