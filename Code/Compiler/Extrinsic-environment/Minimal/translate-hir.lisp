(cl:in-package #:sicl-minimal-extrinsic-environment)

(defclass source-information ()
  ((%positions :initform '() :accessor positions)))

(defun source-position-equal (position1 position2)
  (and (= (sicl-source-tracking:line-index (car position1))
          (sicl-source-tracking:line-index (car position2)))
       (= (sicl-source-tracking:character-index (car position1))
          (sicl-source-tracking:character-index (car position2)))
       (= (sicl-source-tracking:line-index (cdr position1))
          (sicl-source-tracking:line-index (cdr position2)))
       (= (sicl-source-tracking:character-index (cdr position1))
          (sicl-source-tracking:character-index (cdr position2)))))

(defvar *source-information*)

(defun record-origin (instruction)
  (let ((origin (cleavir-ir:origin instruction)))
    (unless (null origin)
      (pushnew origin (positions *source-information*)
               :test #'source-position-equal))))

(defclass fun (closer-mop:funcallable-standard-object)
  ((%untied :initform nil :initarg :untied :accessor untied)
   (%arg-forms :initform nil :initarg :arg-forms :accessor arg-forms)
   (%name :initform NIL :accessor name)
   (%source-information :initarg :source-information :reader source-information))
  (:metaclass closer-mop:funcallable-standard-class))

(defmethod print-object ((object fun) stream)
  (print-unreadable-object (object stream)
    (format stream "Host function named: ~s" (name object))))

(defmethod (setf sicl-genv:fdefinition)
    :after ((new-definition fun) function-name environment)
  (setf (name new-definition) function-name))

;;; The first argument to this function is an instruction that has a
;;; single successor.  Whether a GO is required at the end of this
;;; function is determined by the code layout algorithm.  
;;; 
;;; The inputs are forms to be evaluated.  The outputs are symbols
;;; that are names of variables.  STATIC-ENVIRONMENT is a list of
;;; symbols.
(defgeneric translate-simple-instruction
    (instruction inputs outputs static-environment))

(defmethod translate-simple-instruction :before
    (instruction inputs outputs static-environment)
  (declare (ignore inputs outputs static-environment))
  (record-origin instruction))

(defgeneric translate-branch-instruction (instruction inputs outputs successors))

(defmethod translate-branch-intruction :before
    (instruction inputs outputs successors)
  (declare (ignore inputs outputs successors))
  (record-origin instruction))

(defvar *basic-blocks*)

;;; This variable holds an EQ hash table mapping each instruction
;;; to its owner.  The owner is an ENTER-INSTRUCTION.
(defvar *instruction-ownerships*)

;;; This variable holds an EQ hash table mapping each datum to its
;;; owner.  The owner is an ENTER-INSTRUCTION.
(defvar *location-ownerships*)

(defvar *vars*)

(defgeneric translate-datum (datum))

(defmethod translate-datum ((datum cleavir-ir:constant-input))
  (cleavir-ir:value datum))

(defmethod translate-datum ((datum cleavir-ir:immediate-input))
  (cleavir-ir:value datum))

(defun lookup-datum (datum)
  (let ((var (gethash datum *vars*)))
    (when (null var)
      (setf var (gensym))
      (setf (gethash datum *vars*) var))
    var))

(defmethod translate-datum ((datum cleavir-ir:lexical-location))
  (lookup-datum datum))

(defmethod translate-datum ((datum cleavir-ir:values-location))
  (lookup-datum datum))

;;; For a given owner (which can be an ENTER-INSTRUCTION or NIL),
;;; return a list of all the variables (lexical or values) that are
;;; owned by that instruction.
(defun compute-owned-variables (owner)
  (let ((function-p (typep owner 'cleavir-ir:enter-instruction)))
    (loop for var being each hash-key of *location-ownerships*
	    using (hash-value value)
	  when (and (typep var '(or
				 cleavir-ir:lexical-location
				 cleavir-ir:values-location))
		    (eq value (if function-p
				  owner
				  nil)))
	    collect (translate-datum var))))

(defvar *tags*)

;;; This variable holds an EQ hash table, mapping each
;;; ENTER-INSTRUCTION to a GENSYMed symbol that is used to hold the
;;; dynamic environment as it was when the function corresponding to
;;; that ENTER-INSTRUCTION was called.
(defvar *dynamic-environment-variables*)

(defun translate-lambda-list (lambda-list)
  (loop for item in lambda-list
	collect (cond ((member item lambda-list-keywords)
		       item)
		      ((and (listp item) (= (length item) 2))
		       (list (translate-datum (first item))
			     (translate-datum (second item))))
		      ((and (listp item) (= (length item) 3))
		       (list (first item)
			     (translate-datum (second item))
			     (translate-datum (third item))))
		      (t
		       (translate-datum item)))))

(defun layout-basic-block (basic-block static-environment)
  (with-accessors ((first cleavir-basic-blocks:first-instruction)
                   (last cleavir-basic-blocks:last-instruction))
      basic-block
    (append (loop for instruction = first
		    then (first (cleavir-ir:successors instruction))
		  for inputs = (cleavir-ir:inputs instruction)
		  for input-vars = (mapcar #'translate-datum inputs)
		  for outputs = (cleavir-ir:outputs instruction)
		  for output-vars = (mapcar #'translate-datum outputs)
		  until (eq instruction last)
		  collect (translate-simple-instruction
			   instruction input-vars output-vars
			   static-environment))
	    (let* ((inputs (cleavir-ir:inputs last))
		   (input-vars (mapcar #'translate-datum inputs))
		   (outputs (cleavir-ir:outputs last))
		   (output-vars (mapcar #'translate-datum outputs))
		   (successors (cleavir-ir:successors last))
		   (successor-tags (loop for successor in successors
					 collect (gethash successor *tags*))))
	      (if (= (length successors) 1)
		  (list (translate-simple-instruction
			 last input-vars output-vars static-environment)
			`(go ,(gethash (first successors) *tags*)))
		  (list (translate-branch-instruction
			 last input-vars output-vars successor-tags)))))))

(defun layout-procedure (initial-instruction static-environment)
  ;; Make sure we have an ENTER-INSTRUCTION.
  (assert (typep initial-instruction 'cleavir-ir:enter-instruction))
  ;; Make sure we do not already have a variable associated with this
  ;; ENTER-INSTRUCTION for holding the dynamic environment at runtime.
  (assert (null (gethash initial-instruction *dynamic-environment-variables*)))
  (let* (;; Generate a new variable for holding the dynamic
	 ;; environment at runtime.
	 (dynamic-environment-variable (gensym))
	 (basic-blocks (remove initial-instruction
			       *basic-blocks*
			       :test-not #'eq
                               :key #'cleavir-basic-blocks:owner))
	 (first (find initial-instruction basic-blocks
		      :test #'eq :key #'cleavir-basic-blocks:first-instruction))
	 (rest (remove first basic-blocks :test #'eq)))
    (setf (gethash initial-instruction *dynamic-environment-variables*)
	  dynamic-environment-variable)
    ;; Assign tags to all basic block except the first one
    (loop for block in rest
	  for instruction = (cleavir-basic-blocks:first-instruction block)
	  do (setf (gethash instruction *tags*) (gensym)))
    (let ((tagbody
	     `(tagbody
		 ,@(layout-basic-block first static-environment)
		 ,@(loop for basic-block in rest
			 collect (gethash (cleavir-basic-blocks:first-instruction basic-block)
                                          *tags*)
			 append (layout-basic-block
				 basic-block static-environment))))
	  (owned-vars (compute-owned-variables initial-instruction)))
      `(lambda (&rest args)
	 (block nil
	   (let ((,dynamic-environment-variable *dynamic-environment*)
		 ,@owned-vars)
	     (declare (ignorable ,dynamic-environment-variable
				 ,@owned-vars))
	     ,(build-argument-parsing-code
	       (translate-lambda-list
		(cleavir-ir:lambda-list initial-instruction))
	       'args)
	     ,tagbody))))))

(defparameter *hir-to-cl-translation-meter*
  (make-instance 'cleavir-meter:basic-meter
    :name "HIR-to-Common-Lisp translation"))

(defun translate (initial-instruction linkage-environment)
  (cleavir-meter:with-meter (m *hir-to-cl-translation-meter*)
    (let ((*instruction-ownerships*
	    (cleavir-hir-transformations:compute-instruction-owners
	     initial-instruction))
	  (*location-ownerships*
	    (cleavir-hir-transformations:compute-location-owners
	     initial-instruction))
	  (*basic-blocks* (cleavir-basic-blocks:basic-blocks initial-instruction))
	  (*linkage-environment* linkage-environment)
	  (*tags* (make-hash-table :test #'eq))
	  (*vars* (make-hash-table :test #'eq))
	  (*dynamic-environment-variables* (make-hash-table :test #'eq))
          (*source-information* (make-instance 'source-information)))
      (layout-procedure initial-instruction nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on TRANSLATE-SIMPLE-INSTRUCTION.

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:enclose-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (let* ((enter-instruction (cleavir-ir:code instruction))
	 (static-environment (loop repeat (length inputs)
				   collect (gensym)))
	 (temp (gensym))
	 (proc (layout-procedure enter-instruction static-environment))
	 (wrap `(let ,(loop for input in inputs
			    for var in static-environment
			    collect `(,var input))
		  ,proc))
         (source-information *source-information*))
    `(setq ,(first outputs)
	   (let ((,temp (make-instance 'fun
                          :source-information ,source-information)))
	     (closer-mop:set-funcallable-instance-function ,temp ,wrap)
	     ,temp))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:enter-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (declare (ignore inputs outputs))
  (gensym))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:assignment-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  `(setq ,(first outputs) ,(first inputs)))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:funcall-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (let* ((owner (gethash instruction *instruction-ownerships*))
	 (var (gethash owner *dynamic-environment-variables*)))
    `(progn (setf *dynamic-environment* ,var)
	    (setf ,(first outputs)
		  (multiple-value-list (traced-funcall
					,*linkage-environment*
                                        ',(cleavir-ir:origin  instruction)
					,(first inputs)
					,@(rest inputs)))))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:multiple-value-call-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  `(setf ,(first outputs)
	 (multiple-value-list
	  (apply ,(first inputs)
		 (append ,@(rest inputs))))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:tailcall-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (declare (ignore outputs))
  (let* ((owner (gethash instruction *instruction-ownerships*))
	 (var (gethash owner *dynamic-environment-variables*)))
    ;; It is not quite correct to set the dynamic environment to that
    ;; of the current function.  Since it is a tail call it should
    ;; really be set to the dynamic environment of the caller.
    ;; However, no function translated here will alter its dynamic
    ;; run-time environment in any way.  Such modifications are only
    ;; done in host functions.
    `(progn (setf *dynamic-environment* ,var)
	    (return (traced-funcall
		     ,*linkage-environment*
                     ',(cleavir-ir:origin  instruction)
		     ,(first inputs)
		     ,@(rest inputs))))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:the-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (declare (ignore outputs))
  `(unless (traced-funcall
	    ,*linkage-environment*
            ',(cleavir-ir:origin  instruction)
	    (car (load-time-value
		  (sicl-genv:function-cell
		   'typep
		   ,*linkage-environment*)
		  nil))
	    ,(first inputs)
	    ',(cleavir-ir:value-type instruction))
     (traced-funcall
      ,*linkage-environment*
      ',(cleavir-ir:origin  instruction)
      (car (load-time-value
	    (sicl-genv:function-cell
	     'error
	     ,*linkage-environment*)
	    nil))
      'type-error
      :expected-type ',(cleavir-ir:value-type instruction)
      :datum ,(first inputs))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:car-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  `(setq ,(first outputs)
	 (car ,(first inputs))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:cdr-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  `(setq ,(first outputs)
	 (cdr ,(first inputs))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:rplaca-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (declare (ignore outputs))
  `(rplaca ,(first inputs) ,(second inputs)))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:rplacd-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (declare (ignore outputs))
  `(rplacd ,(first inputs) ,(second inputs)))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:aref-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  `(setq ,(first outputs)
	 (row-major-aref
	  (the (,(if (cleavir-ir:simple-p instruction)
		     'simple-array
		     'array)
		,(cleavir-ir:element-type instruction))
	       ,(first inputs))
	  ,(second inputs))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:aset-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment outputs))
  `(setf (row-major-aref
	  (the (,(if (cleavir-ir:simple-p instruction)
		     'simple-array
		     'array)
		,(cleavir-ir:element-type instruction))
	       ,(first inputs))
	  ,(second inputs))
	 ,(third inputs)))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:fdefinition-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  `(setf ,(first outputs)
	 (car (load-time-value
	       (sicl-genv:function-cell ,(first inputs)
                                        ,*linkage-environment*)
	       nil))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:fixed-to-multiple-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  `(setq ,(first outputs)
	 (list ,@inputs)))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:multiple-to-fixed-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (let ((temp (gensym)))
    `(let ((,temp ,(first inputs)))
       (declare (ignorable ,temp))
       ,@(loop for output in outputs
	       collect `(setf ,output (pop ,temp))))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:nop-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (declare (ignore inputs outputs))
  '(progn))

;;; Recall that the FETCH-INSTRUCTION fetches a CELL from the static
;;; environment.  The instruction has two inputs and one output.  The
;;; first input is a lexical variable holding the static environment
;;; and the second is an immediate number that serves as an index into
;;; the static environment.  However, here, we do not represent the
;;; static environment as a vector at run-time, because then we would
;;; have to allocate that vector when we create a closure.  Instead,
;;; we represent the static environment at compile-time as a list of
;;; symbols representing host variables.  The second input of the
;;; instruction will indicate the element in the list to be used.
(defmethod translate-simple-instruction
    ((instruction cleavir-ir:fetch-instruction)
     inputs outputs static-environement)
  `(setq ,(first outputs)
	 ,(second inputs)))

;;; Recall that the READ-CELL instruction has a single input and a
;;; single output.  The input is a lexical location holding a CELL and
;;; the output is the contents of the cell.  Since we represent CELLs
;;; as CONSes, this instruction is implemented by taking the CAR of
;;; the cell.
(defmethod translate-simple-instruction
    ((instruction cleavir-ir:read-cell-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  `(setq ,(first outputs)
	 (car ,(first inputs))))

;;; Recall that the WRITE-CELL instruction has two inputs.  The first
;;; input is a lexical location holding a CELL and the second input is
;;; the value to be written to the cell.  Since we represent CELLs as
;;; CONSes, this instruction is implemented by SETF-ing the CAR of the
;;; CONS cell.
(defmethod translate-simple-instruction
    ((instruction cleavir-ir:write-cell-instruction)
     inputs outputs static-environment)
  (declare (ignore outputs static-environment))
  `(setq (car ,(first inputs))
	 ,(second inputs)))

;;; Recall that the CREATE-CELL instruction has a single output,
;;; namely a lexical location that will hold the CELL that is being
;;; created by the instruction.  Since we represent cells as CONSes,
;;; this instruction is implemented by calling LIST to allocate a list
;;; with a single element NIL and assigning that list to the lexical
;;; location.
(defmethod translate-simple-instruction
    ((instruction cleavir-ir:create-cell-instruction)
     inputs outputs static-environment)
  (declare (ignore inputs static-environment))
  `(setq ,(first outputs)
	 (list nil)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Methods on TRANSLATE-BRANCH-INSTRUCTION.

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:eq-instruction) inputs outputs successors)
  `(if (eq ,(first inputs) ,(second inputs))
       (go ,(first successors))
       (go ,(second successors))))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:typeq-instruction) inputs outputs successors)
  `(if (traced-funcall
	,*linkage-environment*
        ',(cleavir-ir:origin  instruction)
	(car (load-time-value
	      (sicl-genv:function-cell
	       'typep
	       ,*linkage-environment*)
	      nil))
	,(first inputs)
	',(cleavir-ir:value-type instruction))
       (go ,(second successors))
       (go ,(first successors))))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:fixnum-add-instruction) inputs outputs successors)
  (let ((result (gensym)))
    `(let ((,result (+ ,(first inputs) ,(second inputs))))
       (cond ((typep result 'fixnum)
	      (setq ,(first outputs) ,result)
	      (go ,(first successors)))
	     ((plusp ,result)
	      (setq ,(first outputs)
		    (+ ,result (* 2 most-negative-fixnum)))
	      (go ,(second successors)))
	     (t
	      (setq ,(first outputs)
		    (- ,result (* 2 most-negative-fixnum)))
	      (go ,(second successors)))))))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:fixnum-sub-instruction) inputs outputs successors)
  (let ((result (gensym)))
    `(let ((,result (- ,(first inputs) ,(second inputs))))
       (cond ((typep result 'fixnum)
	      (setq ,(first outputs) ,result)
	      (go ,(first successors)))
	     ((plusp ,result)
	      (setq ,(first outputs)
		    (+ ,result (* 2 most-negative-fixnum)))
	      (go ,(second successors)))
	     (t
	      (setq ,(first outputs)
		    (- ,result (* 2 most-negative-fixnum)))
	      (go ,(second successors)))))))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:fixnum-less-instruction) inputs outputs successors)
  (declare (ignore outputs))
  `(if (< ,(first inputs) ,(second inputs))
       (go ,(first successors))
       (go ,(second successors))))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:fixnum-not-greater-instruction) inputs outputs successors)
  (declare (ignore outputs))
  `(if (<= ,(first inputs) ,(second inputs))
       (go ,(first successors))
       (go ,(second successors))))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:fixnum-equal-instruction) inputs outputs successors)
  (declare (ignore outputs))
  `(if (= ,(first inputs) ,(second inputs))
       (go ,(first successors))
       (go ,(second successors))))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:return-instruction) inputs outputs successors)
  (declare (ignore successors))
  `(return (apply #'values ,(first inputs))))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:catch-instruction) inputs outputs successors)
  (declare (ignore inputs outputs))
  `(go ,(first successors)))

(defmethod translate-branch-instruction
    ((instruction cleavir-ir:unwind-instruction) inputs outputs successors)
  ;; The host lisp handles the dynamic extent of returns, so we don't need the input.
  (declare (ignore inputs outputs))
  (let* ((destination (cleavir-ir:destination instruction))
         (dynamic-environment-variable
	  (gethash (gethash destination *instruction-ownerships*)
		   *dynamic-environment-variables*)))
    `(progn (unwind ,dynamic-environment-variable)
            (go ,(gethash (second (cleavir-ir:successors destination)) *tags*)))))

(defmethod translate-simple-instruction
    ((instruction cleavir-ir:unwind-instruction)
     inputs outputs static-environment)
  (declare (ignore static-environment))
  (declare (ignore inputs outputs)))

;;; When the FUNCALL-INSTRUCTION is the last instruction of a basic
;;; block, it is because there is a call to a function that will never
;;; return, such as ERROR, and the instruction then has no successors
;;; (which is why it is at the end of the basic block).
;;;
;;; We therefore must provide a method on TRANSLATE-BRANCH-INSTRUCTION
;;; (in addition to the method on TRANSLATE-SIMPLE-INSTRUCTION)
;;; specialized to FUNCALL-INSTRUCTION.
(defmethod translate-branch-instruction
    ((instruction cleavir-ir:funcall-instruction) inputs outputs successors)
  (declare (ignore outputs successors))
  (let* ((owner (gethash instruction *instruction-ownerships*))
	 (var (gethash owner *dynamic-environment-variables*)))
    `(progn (setf *dynamic-environment* ,var)
	    (traced-funcall
	     ,*linkage-environment*
             ',(cleavir-ir:origin  instruction)
	     ,(first inputs)
	     ,@(rest inputs)))))
