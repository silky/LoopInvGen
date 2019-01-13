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
	  ConstInt
	  (Variable Int)
	  (+ IntExpr IntExpr)
	  (- IntExpr IntExpr)
	  (* ConstIntExpr IntExpr)
  ))
  (ConstIntExpr Int (
	  ConstInt
	  (+ ConstIntExpr ConstIntExpr)
	  (- ConstIntExpr ConstIntExpr)
	  (* ConstIntExpr ConstIntExpr)
  ))
  (ConstInt Int ((Constant Int)))
)
