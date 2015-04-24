(cl:in-package #:huang-langston)

;;; Exchange two blocks of length LENGTH.  The first block starts at
;;; index START1 and the second block starts at index START2.  Blocks
;;; do not overlap.
(defun blockswap (vector start1 start2 length)
  (loop for i from start1
	for j from start2
	repeat length
	do (rotatef (aref vector i) (aref vector j))))

;;; Reverse the elements of a block of length LENGTH starting at index
;;; START.
(defun reverse-block (vector start length)
  (loop for i from start
	for j downfrom (+ start length -1)
	repeat (floor length 2)
	do (rotatef (aref vector i) (aref vector j))))
