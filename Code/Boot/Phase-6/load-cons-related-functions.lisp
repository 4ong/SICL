(cl:in-package #:sicl-boot-phase-6)

(defun load-cons-related-functions (e5)
  (load-fasl "Cons/null-defun.fasl" e5)
  (load-fasl "Cons/list-defun.fasl" e5)
  (load-fasl "Cons/list-star-defun.fasl" e5)
  (load-fasl "Cons/list-length-defun.fasl" e5)
  (load-fasl "Cons/make-list-defun.fasl" e5)
  (load-fasl "Cons/intersection-defun.fasl" e5)
  (load-fasl "Cons/nintersection-defun.fasl" e5)
  (load-fasl "Cons/set-difference-defun.fasl" e5)
  (load-fasl "Cons/nset-difference-defun.fasl" e5)
  (load-fasl "Cons/nset-exclusive-or-defun.fasl" e5)
  (load-fasl "Cons/endp-defun.fasl" e5)
  (load-fasl "Cons/member-defun.fasl" e5)
  (load-fasl "Cons/member-if-defun.fasl" e5)
  (load-fasl "Cons/member-if-not-defun.fasl" e5)
  (load-fasl "Cons/acons-defun.fasl" e5)
  (load-fasl "Cons/adjoin-defun.fasl" e5)
  (load-fasl "Cons/append-defun.fasl" e5)
  (load-fasl "Cons/nconc-defun.fasl" e5)
  (load-fasl "Cons/nreconc-defun.fasl" e5)
  (load-fasl "Cons/assoc-defun.fasl" e5)
  (load-fasl "Cons/assoc-if-defun.fasl" e5)
  (load-fasl "Cons/assoc-if-not-defun.fasl" e5)
  (load-fasl "Cons/butlast-defun.fasl" e5)
  (load-fasl "Cons/nbutlast-defun.fasl" e5)
  (load-fasl "Cons/copy-alist-defun.fasl" e5)
  (load-fasl "Cons/copy-list-defun.fasl" e5)
  (load-fasl "Cons/copy-tree-defun.fasl" e5)
  (load-fasl "Cons/getf-defun.fasl" e5)
  (load-fasl "Cons/get-properties-defun.fasl" e5)
  (load-fasl "Cons/last-defun.fasl" e5)
  (load-fasl "Cons/make-bindings-defun.fasl" e5)
  (load-fasl "Cons/mapcar-defun.fasl" e5)
  (load-fasl "Cons/mapcan-defun.fasl" e5)
  (load-fasl "Cons/mapc-defun.fasl" e5)
  (load-fasl "Cons/mapcon-defun.fasl" e5)
  (load-fasl "Cons/mapl-defun.fasl" e5)
  (load-fasl "Cons/maplist-defun.fasl" e5)
  (load-fasl "Cons/nsublis-defun.fasl" e5)
  (load-fasl "Cons/nsubst-defun.fasl" e5))
