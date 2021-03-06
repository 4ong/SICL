(cl:in-package #:sicl-sequence)

(defgeneric copy-seq
    (sequence)
  (:generic-function-class fast-generic-function))

(defgeneric elt
    (sequence index)
  (:generic-function-class fast-generic-function))

(defgeneric (setf elt)
    (value sequence index)
  (:generic-function-class fast-generic-function))

(defgeneric fill
    (sequence item &key start end)
  (:generic-function-class fast-generic-function))

(defgeneric make-sequence-like
    (sequence length &key initial-element initial-contents)
  (:generic-function-class fast-generic-function))

(defgeneric adjust-sequence
    (sequence length &key initial-element initial-contents)
  (:generic-function-class fast-generic-function))

(defgeneric subseq
    (sequence start &optional end)
  (:generic-function-class fast-generic-function))

(defgeneric map-into
    (result-sequence function &rest sequences)
  (:generic-function-class fast-generic-function))

(defgeneric reduce
    (function sequence &key key from-end start end initial-value)
  (:generic-function-class fast-generic-function))

(defgeneric count
    (item sequence &key from-end start end key test test-not)
  (:generic-function-class fast-generic-function))

(defgeneric count-if
    (predicate sequence &key from-end start end key)
  (:generic-function-class fast-generic-function))

(defgeneric count-if-not
    (predicate sequence &key from-end start end key)
  (:generic-function-class fast-generic-function))

(defgeneric length
    (sequence)
  (:generic-function-class fast-generic-function))

(defgeneric reverse
    (sequence)
  (:generic-function-class fast-generic-function))

(defgeneric nreverse
    (sequence)
  (:generic-function-class fast-generic-function))

(defgeneric sort
    (sequence predicate &key key)
  (:generic-function-class fast-generic-function))

(defgeneric stable-sort
    (sequence predicate &key key)
  (:generic-function-class fast-generic-function))

(defgeneric find
    (item sequence &key from-end test test-not start end key)
  (:generic-function-class fast-generic-function))

(defgeneric find-if
    (predicate sequence &key from-end start end key)
  (:generic-function-class fast-generic-function))

(defgeneric find-if-not
    (predicate sequence &key from-end start end key)
  (:generic-function-class fast-generic-function))

(defgeneric position
    (item sequence &key from-end test test-not start end key)
  (:generic-function-class fast-generic-function))

(defgeneric position-if
    (predicate sequence &key from-end start end key)
  (:generic-function-class fast-generic-function))

(defgeneric position-if-not
    (predicate sequence &key from-end start end key)
  (:generic-function-class fast-generic-function))

(defgeneric search
    (sequence-1 sequence-2 &key from-end test test-not key start1 start2 end1 end2)
  (:generic-function-class fast-generic-function))

(defgeneric mismatch
    (sequence-1 sequence-2 &key from-end test test-not key start1 start2 end1 end2)
  (:generic-function-class fast-generic-function))

(defgeneric replace
    (sequence-1 sequence-2 &key start1 end1 start2 end2)
  (:generic-function-class fast-generic-function))

(defgeneric substitute
    (newitem olditem sequence &key from-end test test-not start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric substitute-if
    (newitem predicate sequence &key from-end start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric substitute-if-not
    (newitem predicate sequence &key from-end start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric nsubstitute
    (newitem olditem sequence &key from-end test test-not start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric nsubstitute-if
    (newitem predicate sequence &key from-end start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric nsubstitute-if-not
    (newitem predicate sequence &key from-end start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric remove
    (item sequence &key from-end test test-not start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric remove-if
    (test sequence &key from-end start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric remove-if-not
    (test sequence &key from-end start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric delete
    (item sequence &key from-end test test-not start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric delete-if
    (test sequence &key from-end start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric delete-if-not
    (test sequence &key from-end start end count key)
  (:generic-function-class fast-generic-function))

(defgeneric remove-duplicates
    (sequence &key from-end test test-not start end key)
  (:generic-function-class fast-generic-function))

(defgeneric delete-duplicates
    (sequence &key from-end test test-not start end key)
  (:generic-function-class fast-generic-function))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;
;;; Auxiliary Functions

(defgeneric make-sequence-reader
    (sequence start end from-end terminate)
  (:generic-function-class fast-generic-function))

(defgeneric make-sequence-writer
    (sequence start end from-end terminate)
  (:generic-function-class fast-generic-function))
