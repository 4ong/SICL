(cl:in-package #:sicl-bucket-hash-table)

(defclass bucket-hash-table (hash-table)
  ((size :initarg :size
         :initform 16
         :accessor %bucket-hash-table-size
         :reader hash-table-size)
   (data :accessor hash-table-data)
   (count :initform 0
          :accessor %bucket-hash-table-count
          :reader hash-table-count))
  (:metaclass built-in-class))
  
(setf sicl-hash-table:*default-hash-table-class* (find-class 'bucket-hash-table))
