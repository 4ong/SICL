(cl:in-package :sicl-cons-high)

;;;; Copyright (c) 2008 - 2015
;;;;
;;;;     Robert Strandh (robert.strandh@gmail.com)
;;;;
;;;; all rights reserved. 
;;;;
;;;; Permission is hereby granted to use this software for any 
;;;; purpose, including using, modifying, and redistributing it.
;;;;
;;;; The software is provided "as-is" with no warranty.  The user of
;;;; this software assumes any responsibility of the consequences. 

;;;; This file is part of the cons-high module of the SICL project.
;;;; See the file SICL.text for a description of the project. 
;;;; See the file cons-high.text for a description of the module.

;;; special version of last used when the second argument to
;;; last is 1. 
(eval-when (:compile-toplevel :load-toplevel :execute)
  (defun last-1 (list)
    (unless (typep list 'list)
      (error 'must-be-list
	     :datum list
	     :name 'last))
    ;; We can use for ... on, because it uses atom to test for
    ;; the end of the list. 
    (loop for rest on list
	  do (setf list rest))
    list))

(define-compiler-macro last (&whole form list &optional (n 1))
  (if (eql n 1)
      `(last-1 ,list)
      form))


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function acons

(defun acons (key datum alist)
  (cons (cons key datum) alist))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function pairlis

;;; The hyperspec says the consequences are undefined if the two
;;; lists do not have the same length.  We check for this situation
;;; and signal an error in that case. 

(defun pairlis (keys data &optional alist)
  (loop with result = alist
	with remaining-keys = keys
	with remaining-data = data
	until (or (atom remaining-keys) (atom remaining-data))
	do (push (cons (pop remaining-keys) (pop remaining-data)) result)
	finally (unless (and (null remaining-keys) (null remaining-data))
		  (cond ((and (atom remaining-keys) (not (null remaining-keys)))
			 (error 'must-be-proper-list
				:datum keys
				:name 'pairlis))
			((and (atom remaining-data) (not (null remaining-data)))
			 (error 'must-be-proper-list
				:datum data
				:name 'pairlis))
			(t
			 (error 'lists-must-have-the-same-length
				:list1 keys
				:list2 data
				:name 'pairlis))))
		(return result)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function copy-alist

;;; The HyperSpec says that the argument is an alist, and 
;;; in those cases, whenever the type doesn't correspond, it
;;; is legitimate to signal an error.  However, for copy-alist,
;;; the HyperSpec also says that any object that is referred to
;;; directly or indirectly is still shared betwee the argument
;;; and the resulting list, which suggests that any element that
;;; is not a cons should just be included in the resulting
;;; list as well.  And that is what we are doing. 

;;; We use (loop for ... on ...) because it uses ATOM to test for
;;; the end of the list.  Then we check that the atom is really 
;;; null, and if not, signal a type error.

(defun copy-alist (alist)
  (loop for remaining on alist
	collect (if (consp (car remaining))
		    (cons (caar remaining) (cdar remaining))
		    (car remaining))
	finally (unless (null remaining)
		  (error 'must-be-proper-list
			 :datum alist
			 :name 'copy-alist))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function tailp

;;; We could use (loop for ... on ...) here for consistency. 

(defun tailp (object list)
  (loop for rest = list then (cdr rest)
	until (atom rest)
	when (eql object rest)
	  return t
	finally (return (eql object rest))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function ldiff

(defun ldiff (list object)
  (if (or (eql list object) (atom list))
      nil
      (let* ((result (list (car list)))
             (current result)
             (remaining (cdr list)))
        (loop until (or (eql remaining object) (atom remaining))
              do (setf (cdr current) (list (car remaining)))
                 (setf current (cdr current))
                 (setf remaining (cdr remaining)))
        (if (eql remaining object)
            result
            (progn (setf (cdr current) remaining)
                   result)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function adjoin

(defun |adjoin key=identity test=eq| (name item list)
  (if (|member test=eq key=identity| name item list)
      list
      (cons item list)))

(defun |adjoin key=identity test=eql| (name item list)
  (if (|member test=eql key=identity| name item list)
      list
      (cons item list)))

(defun |adjoin key=identity test=other| (name item list test)
  (if (|member test=other key=identity| name item list test)
      list
      (cons item list)))

(defun |adjoin key=identity test-not=other| (name item list test-not)
  (if (|member test-not=other key=identity| name item list test-not)
      list
      (cons item list)))

(defun |adjoin key=other test=eq| (name item list key)
  (if (|member test=eq key=other| name (funcall key item) list key)
      list
      (cons item list)))

(defun |adjoin key=other test=eql| (name item list key)
  (if (|member test=eql key=other| name (funcall key item) list key)
      list
      (cons item list)))

(defun |adjoin key=other test=other| (name item list key test)
  (if (|member test=other key=other| name (funcall key item) list test key)
      list
      (cons item list)))

(defun |adjoin key=other test-not=other| (name item list key test-not)
  (if (|member test-not=other key=other| name (funcall key item) list test-not key)
      list
      (cons item list)))

(defun adjoin (item list 
	       &key key (test nil test-given) (test-not nil test-not-given))
  (when (and test-given test-not-given)
    (error 'both-test-and-test-not-given :name 'adjoin))
  (if key
      (if test-given
	  (if (or (eq test #'eq) (eq test 'eq))
	      (|adjoin key=other test=eq| 'adjoin item list key)
	      (if (or (eq test #'eql) (eq test 'eql))
		  (|adjoin key=other test=eql| 'adjoin item list key)
		  (|adjoin key=other test=other| 'adjoin item list key test)))
	  (if test-not-given
	      (|adjoin key=other test-not=other| 'adjoin item list key test-not)
	      (|adjoin key=other test=eql| 'adjoin item list key)))
      (if test-given
	  (if (or (eq test #'eq) (eq test 'eq))
	      (|adjoin key=identity test=eq| 'adjoin item list)
	      (if (or (eq test #'eql) (eq test 'eql))
		  (|adjoin key=identity test=eql| 'adjoin item list)
		  (|adjoin key=identity test=other| 'adjoin item list test)))
	  (if test-not-given
	      (|adjoin key=identity test-not=other| 'adjoin item list test-not)
	      (|adjoin key=identity test=eql| 'adjoin item list)))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function set-exclusive-or

(defun |set-exclusive-or key=identity test=eql| (name list1 list2)
  (let ((result '()))
    (with-proper-list-elements (element list1 name)
      (unless (|member test=eql key=identity| name element list2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (|member test=eql key=identity| name element list1)
	(push element result)))
    result))

(defun |set-exclusive-or key=identity test=eq| (name list1 list2)
  (let ((result '()))
    (with-proper-list-elements (element list1 name)
      (unless (|member test=eq key=identity| name element list2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (|member test=eq key=identity| name  element list1)
	(push element result)))
    result))

(defun |set-exclusive-or key=other test=eql| (name list1 list2 key)
  (let ((result '()))
    (with-proper-list-elements (element list1 name)
      (unless (|member test=eql key=other| name (funcall key element) list2 key)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (|member test=eql key=other| name (funcall key element) list1 key)
	(push element result)))
    result))

(defun |set-exclusive-or key=other test=eq| (name list1 list2 key)
  (let ((result '()))
    (with-proper-list-elements (element list1 name)
      (unless (|member test=eq key=other| name (funcall key element) list2 key)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (|member test=eq key=other| name (funcall key element) list1 key)
	(push element result)))
    result))

(defun |set-exclusive-or key=identity test=other| (name list1 list2 test)
  (let ((result '()))
    (with-proper-list-elements (element1 list1 name)
      (unless (|member test=other key=identity| name element1 list2 test)
	(push element1 result)))
    ;; we need to use a member with a test with reversed order or arguments
    (with-proper-list-elements (element2 list2 name)
      (unless (|member reversed test=other key=identity| name element2 list1 test)
	(push element2 result)))
    result))

(defun |set-exclusive-or key=other test=other| (name list1 list2 key test)
  (let ((result '()))
    (with-proper-list-elements (element1 list1 name)
      (unless (|member test=other key=other| name (funcall key element1) list2 test key)
	(push element1 result)))
    ;; we need to use a member with a test with reversed order or arguments
    (with-proper-list-elements (element2 list2 name)
      (unless (|member reversed test=other key=other| name (funcall key element2) list1 test key)
	(push element2 result)))
    result))

(defun |set-exclusive-or key=identity test-not=other| (name list1 list2 test-not)
  (let ((result '()))
    (with-proper-list-elements (element1 list1 name)
      (unless (|member test-not=other key=identity| name element1 list2 test-not)
	(push element1 result)))
    ;; we need to use a member with a test with reversed order or arguments
    (with-proper-list-elements (element2 list2 name)
      (unless (|member reversed test-not=other key=identity| name element2 list1 test-not)
	(push element2 result)))
    result))

(defun |set-exclusive-or key=other test-not=other| (name list1 list2 key test-not)
  (let ((result '()))
    (with-proper-list-elements (element1 list1 name)
      (unless (|member test-not=other key=other| name (funcall key element1) list2 test-not key)
	(push element1 result)))
    ;; we need to use a member with a test with reversed order or arguments
    (with-proper-list-elements (element2 list2 name)
      (unless (|member reversed test-not=other key=other| name (funcall key element2) list1 test-not key)
	(push element2 result)))
    result))

(defun |set-exclusive-or key=identity test=eq hash| (name list1 list2)
  (let ((table1 (make-hash-table :test #'eq))
	(table2 (make-hash-table :test #'eq))
	(result '()))
    (with-proper-list-elements (element list1 name)
      (setf (gethash element table1) t))
    (with-proper-list-elements (element list2 name)
      (setf (gethash element table2) t))
    (with-proper-list-elements (element list1 name)
      (unless (gethash element table2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (gethash element table1)
	(push element result)))
    result))

(defun |set-exclusive-or key=identity test=eql hash| (name list1 list2)
  (let ((table1 (make-hash-table :test #'eql))
	(table2 (make-hash-table :test #'eql))
	(result '()))
    (with-proper-list-elements (element list1 name)
      (setf (gethash element table1) t))
    (with-proper-list-elements (element list2 name)
      (setf (gethash element table2) t))
    (with-proper-list-elements (element list1 name)
      (unless (gethash element table2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (gethash element table1)
	(push element result)))
    result))

(defun |set-exclusive-or key=identity test=equal hash| (name list1 list2)
  (let ((table1 (make-hash-table :test #'equal))
	(table2 (make-hash-table :test #'equal))
	(result '()))
    (with-proper-list-elements (element list1 name)
      (setf (gethash element table1) t))
    (with-proper-list-elements (element list2 name)
      (setf (gethash element table2) t))
    (with-proper-list-elements (element list1 name)
      (unless (gethash element table2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (gethash element table1)
	(push element result)))
    result))

(defun |set-exclusive-or key=identity test=equalp hash| (name list1 list2)
  (let ((table1 (make-hash-table :test #'equalp))
	(table2 (make-hash-table :test #'equalp))
	(result '()))
    (with-proper-list-elements (element list1 name)
      (setf (gethash element table1) t))
    (with-proper-list-elements (element list2 name)
      (setf (gethash element table2) t))
    (with-proper-list-elements (element list1 name)
      (unless (gethash element table2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (gethash element table1)
	(push element result)))
    result))

(defun |set-exclusive-or key=other test=eq hash| (name list1 list2 key)
  (let ((table1 (make-hash-table :test #'eq))
	(table2 (make-hash-table :test #'eq))
	(result '()))
    (with-proper-list-elements (element list1 name)
      (setf (gethash (funcall key element) table1) t))
    (with-proper-list-elements (element list2 name)
      (setf (gethash (funcall key element) table2) t))
    (with-proper-list-elements (element list1 name)
      (unless (gethash (funcall key element) table2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (gethash (funcall key element) table1)
	(push element result)))
    result))

(defun |set-exclusive-or key=other test=eql hash| (name list1 list2 key)
  (let ((table1 (make-hash-table :test #'eql))
	(table2 (make-hash-table :test #'eql))
	(result '()))
    (with-proper-list-elements (element list1 name)
      (setf (gethash (funcall key element) table1) t))
    (with-proper-list-elements (element list2 name)
      (setf (gethash (funcall key element) table2) t))
    (with-proper-list-elements (element list1 name)
      (unless (gethash (funcall key element) table2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (gethash (funcall key element) table1)
	(push element result)))
    result))

(defun |set-exclusive-or key=other test=equal hash| (name list1 list2 key)
  (let ((table1 (make-hash-table :test #'equal))
	(table2 (make-hash-table :test #'equal))
	(result '()))
    (with-proper-list-elements (element list1 name)
      (setf (gethash (funcall key element) table1) t))
    (with-proper-list-elements (element list2 name)
      (setf (gethash (funcall key element) table2) t))
    (with-proper-list-elements (element list1 name)
      (unless (gethash (funcall key element) table2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (gethash (funcall key element) table1)
	(push element result)))
    result))

(defun |set-exclusive-or key=other test=equalp hash| (name list1 list2 key)
  (let ((table1 (make-hash-table :test #'equalp))
	(table2 (make-hash-table :test #'equalp))
	(result '()))
    (with-proper-list-elements (element list1 name)
      (setf (gethash (funcall key element) table1) t))
    (with-proper-list-elements (element list2 name)
      (setf (gethash (funcall key element) table2) t))
    (with-proper-list-elements (element list1 name)
      (unless (gethash (funcall key element) table2)
	(push element result)))
    (with-proper-list-elements (element list2 name)
      (unless (gethash (funcall key element) table1)
	(push element result)))
    result))

(defun set-exclusive-or (list1 list2
			 &key key (test nil test-given) (test-not nil test-not-given))
  (when (and test-given test-not-given)
    (error 'both-test-and-test-not-given :name 'set-exclusive-or))
  (let ((use-hash (> (* (length list1) (length list2)) 1000)))
    (if key
	(if test-given
	    (cond ((or (eq test #'eq) (eq test 'eq))
		   (if use-hash
		       (|set-exclusive-or key=other test=eq hash| 'set-exclusive-or list1 list2 key)
		       (|set-exclusive-or key=other test=eq| 'set-exclusive-or list1 list2 key)))
		  ((or (eq test #'eql) (eq test 'eql))
		   (if use-hash
		       (|set-exclusive-or key=other test=eql hash| 'set-exclusive-or list1 list2 key)
		       (|set-exclusive-or key=other test=eql| 'set-exclusive-or list1 list2 key)))
		  ((or (eq test #'equal) (eq test 'equal))
		   (if use-hash
		       (|set-exclusive-or key=other test=equal hash| 'set-exclusive-or list1 list2 key)
		       (|set-exclusive-or key=other test=other| 'set-exclusive-or list1 list2 key #'equal)))
		  ((or (eq test #'equalp) (eq test 'equalp))
		   (if use-hash
		       (|set-exclusive-or key=other test=equalp hash| 'set-exclusive-or list1 list2 key)
		       (|set-exclusive-or key=other test=other| 'set-exclusive-or list1 list2 key #'equalp)))
		  (t
		   (|set-exclusive-or key=other test=other| 'set-exclusive-or list1 list2 key test)))
	    (if test-not-given
		(|set-exclusive-or key=other test-not=other| 'set-exclusive-or list1 list2 key test-not)
		(if use-hash
		    (|set-exclusive-or key=other test=eql hash| 'set-exclusive-or list1 list2 key)
		    (|set-exclusive-or key=other test=eql| 'set-exclusive-or list1 list2 key))))
	(if test-given
	    (cond ((or (eq test #'eq) (eq test 'eq))
		   (if use-hash
		       (|set-exclusive-or key=identity test=eq hash| 'set-exclusive-or list1 list2)
		       (|set-exclusive-or key=identity test=eq| 'set-exclusive-or list1 list2)))
		  ((or (eq test #'eql) (eq test 'eql))
		   (if use-hash
		       (|set-exclusive-or key=identity test=eql hash| 'set-exclusive-or list1 list2)
		       (|set-exclusive-or key=identity test=eql| 'set-exclusive-or list1 list2)))
		  ((or (eq test #'equal) (eq test 'equal))
		   (if use-hash
		       (|set-exclusive-or key=identity test=equal hash| 'set-exclusive-or list1 list2)
		       (|set-exclusive-or key=identity test=other| 'set-exclusive-or list1 list2 #'equal)))
		  ((or (eq test #'equalp) (eq test 'equalp))
		   (if use-hash
		       (|set-exclusive-or key=identity test=equalp hash| 'set-exclusive-or list1 list2)
		       (|set-exclusive-or key=identity test=other| 'set-exclusive-or list1 list2 #'equalp)))
		  (t
		   (|set-exclusive-or key=identity test=other| 'set-exclusive-or list1 list2 test)))
	    (if test-not-given
		(|set-exclusive-or key=identity test-not=other| 'set-exclusive-or list1 list2 test-not)
		(if use-hash
		    (|set-exclusive-or key=identity test=eql hash| 'set-exclusive-or list1 list2)
		    (|set-exclusive-or key=identity test=eql| 'set-exclusive-or list1 list2)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function nset-exclusive-or

;;; We take advantage of the fact that the standard doesn't 
;;; require this function to have any side effects. 

(defun nset-exclusive-or (list1 list2
			  &key key (test nil test-given) (test-not nil test-not-given))
  (when (and test-given test-not-given)
    (error 'both-test-and-test-not-given :name 'nset-exclusive-or))
  (let ((use-hash (> (* (length list1) (length list2)) 1000)))
    (if key
	(if test-given
	    (cond ((or (eq test #'eq) (eq test 'eq))
		   (if use-hash
		       (|set-exclusive-or key=other test=eq hash| 'nset-exclusive-or list1 list2 key)
		       (|set-exclusive-or key=other test=eq| 'nset-exclusive-or list1 list2 key)))
		  ((or (eq test #'eql) (eq test 'eql))
		   (if use-hash
		       (|set-exclusive-or key=other test=eql hash| 'nset-exclusive-or list1 list2 key)
		       (|set-exclusive-or key=other test=eql| 'nset-exclusive-or list1 list2 key)))
		  ((or (eq test #'equal) (eq test 'equal))
		   (if use-hash
		       (|set-exclusive-or key=other test=equal hash| 'nset-exclusive-or list1 list2 key)
		       (|set-exclusive-or key=other test=other| 'nset-exclusive-or list1 list2 key #'equal)))
		  ((or (eq test #'equalp) (eq test 'equalp))
		   (if use-hash
		       (|set-exclusive-or key=other test=equalp hash| 'nset-exclusive-or list1 list2 key)
		       (|set-exclusive-or key=other test=other| 'nset-exclusive-or list1 list2 key #'equalp)))
		  (t
		   (|set-exclusive-or key=other test=other| 'nset-exclusive-or list1 list2 key test)))
	    (if test-not-given
		(|set-exclusive-or key=other test-not=other| 'nset-exclusive-or list1 list2 key test-not)
		(if use-hash
		    (|set-exclusive-or key=other test=eql hash| 'nset-exclusive-or list1 list2 key)
		    (|set-exclusive-or key=other test=eql| 'nset-exclusive-or list1 list2 key))))
	(if test-given
	    (cond ((or (eq test #'eq) (eq test 'eq))
		   (if use-hash
		       (|set-exclusive-or key=identity test=eq hash| 'nset-exclusive-or list1 list2)
		       (|set-exclusive-or key=identity test=eq| 'nset-exclusive-or list1 list2)))
		  ((or (eq test #'eql) (eq test 'eql))
		   (if use-hash
		       (|set-exclusive-or key=identity test=eql hash| 'nset-exclusive-or list1 list2)
		       (|set-exclusive-or key=identity test=eql| 'nset-exclusive-or list1 list2)))
		  ((or (eq test #'equal) (eq test 'equal))
		   (if use-hash
		       (|set-exclusive-or key=identity test=equal hash| 'nset-exclusive-or list1 list2)
		       (|set-exclusive-or key=identity test=other| 'nset-exclusive-or list1 list2 #'equal)))
		  ((or (eq test #'equalp) (eq test 'equalp))
		   (if use-hash
		       (|set-exclusive-or key=identity test=equalp hash| 'nset-exclusive-or list1 list2)
		       (|set-exclusive-or key=identity test=other| 'nset-exclusive-or list1 list2 #'equalp)))
		  (t
		   (|set-exclusive-or key=identity test=other| 'nset-exclusive-or list1 list2 test)))
	    (if test-not-given
		(|set-exclusive-or key=identity test-not=other| 'nset-exclusive-or list1 list2 test-not)
		(if use-hash
		    (|set-exclusive-or key=identity test=eql hash| 'nset-exclusive-or list1 list2)
		    (|set-exclusive-or key=identity test=eql| 'nset-exclusive-or list1 list2)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Function getf

(defun getf (plist indicator &optional default)
  (unless (typep plist 'list)
    (error 'must-be-property-list
	   :datum plist
	   :name 'getf))
  (loop for rest on plist by #'cddr
	do (unless (consp (cdr rest))
	     (error 'must-be-property-list
		    :datum plist
		    'getf))
	when (eq (car rest) indicator)
	  return (cadr rest)
	finally (unless (null rest)
		  (error 'must-be-property-list
		    :datum plist
		    'getf))
		(return default)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Setf expander for getf

(define-setf-expander getf (place indicator &optional default &environment env)
  (let ((indicator-var (gensym))
	(default-var (gensym))
	(value-var (gensym)))
    (multiple-value-bind (vars vals store-vars writer-form reader-form)
	(get-setf-expansion place env)
      (values (append vars (list indicator-var default-var))
	      (append vals (list indicator default))
	      (list value-var)
	      `(let ((,default-var ,default-var))
		 (declare (ignore ,default-var))
		 (loop for rest on ,reader-form by #'cddr
		       when (eq (car rest) ,indicator-var)
			 do (setf (cadr rest) ,value-var)
			    (return nil)
		       finally (let ((,(car store-vars)
				      (list* ,indicator-var ,value-var ,reader-form)))
				 ,writer-form))
		 ,value-var)
	      `(getf ,reader-form ,indicator-var ,default)))))
[
