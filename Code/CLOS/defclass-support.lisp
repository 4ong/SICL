(cl:in-package #:sicl-clos)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Functions to canonicalize certain parts of the defclass macro

;;; The CLHS requires that the DIRECT-SUPERCLASSES argument to
;;; DEFCLASS be a proper list of non-NIL symbols.

(defun canonicalize-direct-superclass-name (class-name)
  (unless (and (symbolp class-name)
	       (not (null class-name)))
    (error 'class-name-must-be-non-nil-symbol
	   :name 'defclass
	   :datum class-name))
  `',class-name)

(defun canonicalize-direct-superclass-names (direct-superclass-names)
  (unless (proper-list-p direct-superclass-names)
    (error 'superclass-list-must-be-proper-list
	   :name 'defclass
	   :datum direct-superclass-names))
  `(list ,@(loop for name in direct-superclass-names
		 collect (canonicalize-direct-superclass-name name))))

(declaim (notinline make-initfunction))

(defun make-initfunction (form)
  `(lambda () ,form))

(defun canonicalize-direct-slot-spec (direct-slot-spec)
  ;; A direct-slot-spec can be a symbol which is then the
  ;; name of the slot.
  (if (symbolp direct-slot-spec)
      `(:name ',direct-slot-spec)
      (progn
	;; If the direct-slot-spec is not a symbol, it must
	;; be a non-empty proper list.
	(unless (and (proper-list-p direct-slot-spec)
		     (consp direct-slot-spec))
	  (error 'malformed-slot-spec
		 :name 'defclass
		 :datum direct-slot-spec))
	;; In that case, the first element must be the name
	;; of the slot, which must be a symbol.
	(unless (symbolp (car direct-slot-spec))
	  (error 'illegal-slot-name
		 :name 'defclass
		 :datum (car direct-slot-spec)))
	;; The slot options must be a list of even length
	;; where every other element is the name of a slot
	;; option and every other element is the value of
	;; the slot option.
	(unless (evenp (length (cdr direct-slot-spec)))
	  (error 'slot-options-must-be-even
		 :name 'defclass
		 :datum direct-slot-spec))
	(let ((ht (make-hash-table :test #'eq)))
	  (loop for (name value) on (cdr direct-slot-spec) by #'cddr
		do (unless (symbolp name)
		     (error 'slot-option-name-must-be-symbol
			    :name 'defclass
			    :datum name))
		   (push value (gethash name ht '())))
	  (let ((result `(:name ',(car direct-slot-spec))))
	    (flet ((add (name value)
		     (setf result (append result (list name value)))))
	      ;; Check and process :initform option.
	      (multiple-value-bind (value flag)
		  (gethash :initform ht)
		(when flag
		  (unless (= (length value) 1)
		    (error 'multiple-initform-options-not-permitted
			   :datum direct-slot-spec))
		  (add :initform `',(car value))
		  (add :initfunction (make-initfunction (car value)))
		  (remhash :initform ht)))
	      ;; Process :initarg option.
	      (multiple-value-bind (value flag)
		  (gethash :initarg ht)
		(when flag
		  (add :initargs `',(reverse value))
		  (remhash :initarg ht)))
	      ;; Turn :accessor into :reader and :writer
	      (multiple-value-bind (value flag)
		  (gethash :accessor ht)
		(when flag
		  (loop for accessor in value
			do (push accessor (gethash :reader ht '()))
			   (push `(setf ,accessor) (gethash :writer ht '())))
		  (remhash :accessor ht)))
	      ;; Process :reader option.
	      (multiple-value-bind (value flag)
		  (gethash :reader ht)
		(when flag
		  (add :readers `',(reverse value))
		  (remhash :reader ht)))
	      ;; Process :writer option.
	      (multiple-value-bind (value flag)
		  (gethash :writer ht)
		(when flag
		  (add :writers `',(reverse value))
		  (remhash :writer ht)))
	      ;; Check and process :documentation option.
	      (multiple-value-bind (value flag)
		  (gethash :documentation ht)
		(when flag
		  (unless (= (length value) 1)
		    (error 'multiple-documentation-options-not-permitted
			   :datum direct-slot-spec))
		  (unless (stringp (car value))
		    (error 'slot-documentation-option-must-be-string
			   :datum (car value)))
		  (add :documentation (car value))
		  (remhash :documentation ht)))
	      ;; Check and process :allocation option.
	      (multiple-value-bind (value flag)
		  (gethash :allocation ht)
		(when flag
		  (unless (= (length value) 1)
		    (error 'multiple-allocation-options-not-permitted
			   :datum direct-slot-spec))
		  (add :allocation (car value))
		  (remhash :allocation ht)))
	      ;; Check and process :type option.
	      (multiple-value-bind (value flag)
		  (gethash :type ht)
		(when flag
		  (unless (= (length value) 1)
		    (error 'multiple-type-options-not-permitted
			   :datum direct-slot-spec))
		  (add :type (car value))
		  (remhash :type ht)))
	      ;; Add remaining options without checking.
	      (maphash (lambda (name value)
			 (add name (reverse value)))
		       ht))
	    `(list ,@result))))))

(defun canonicalize-direct-slot-specs (direct-slot-specs)
  (when (not (proper-list-p direct-slot-specs))
    (error 'malformed-slots-list
	   :name 'defclass
	   :datum direct-slot-specs))
  `(list ,@(loop for spec in direct-slot-specs
		 collect (canonicalize-direct-slot-spec spec))))

;;; Make sure each class options is well formed, and check that a
;;; class option appears at most once.  Return a list of class
;;; options, including the corresponding keyword argument, to be
;;; spliced into the call to ENSURE-CLASS.
(defun canonicalize-defclass-options (options)
  ;; Check that each option is a non-empty list
  (let ((potential-malformed-option (member-if-not #'consp options)))
    (unless (null potential-malformed-option)
      (error 'class-option-must-be-non-empty-list
	     :name 'defclass
	     :datum (car potential-malformed-option))))
  ;; Check that the name of each option is a symbol
  (let ((potential-malformed-option (member-if-not #'symbolp options :key #'car)))
    (unless (null potential-malformed-option)
      (error 'class-option-name-must-be-symbol
	     :name 'defclass
	     :datum (car potential-malformed-option))))
  ;; Check that there are no duplicate option names
  (let ((reduced-options (remove-duplicates options :key #'car :test #'eq)))
    (when (< (length reduced-options) (length options))
      (loop for option in reduced-options
	    do (when (> (count-list (car option) options
				    :key #'car :test #'eq) 1)
		 (error 'duplicate-class-option-not-allowed
			:name 'defclass
			:datum (car option))))))
  (let ((result '()))
    (loop for option in options
	  do (case (car option)
	       (:default-initargs
		(unless (proper-list-p (cdr option))
		  (error 'malformed-default-initargs
			 :datum option))
		(unless (evenp (length (cdr option)))
		  (error 'malformed-default-initargs
			 :datum option))
		(let ((canonicalized-initargs '()))
		  (loop for (name value) on (cdr option) by #'cddr
			do (unless (symbolp name)
			     (error 'default-initarg-name-must-be-symbol
				    :datum name))
			do (setf canonicalized-initargs
				 (append canonicalized-initargs
					 `((,name ,value (lambda () ,value))))))
		  (setf result
			(append result `(:direct-default-initargs
					 ,canonicalized-initargs)))))
	       (:documentation
		(unless (null (cddr option))
		  (error 'malformed-documentation-option
			 :name 'defclass
			 :datum option))
		(setf result
		      (append result `(:documentation ,(cadr option)))))
	       (:metaclass
		(unless (null (cddr option))
		  (error 'malformed-metaclass-option
			 :name 'defclass
			 :datum option))
		(setf result
		      (append result `(:metaclass ',(cadr option)))))
	       (t 
		(setf result
		      (append result `(,(car option) ,(cdr option)))))))
    result))
