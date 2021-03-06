;; -*- mode: lisp -*-

(in-package :cl-user)

;;;; Quicklisp Setup

;; adapted from quicklisp's lines added by ql:add-to-init-file:

(defparameter *quicklisp-base-pathname* "~/quicklisp/")

(defun quicklisp-set-up-p ()
  (member ':quicklisp *features*))

(defun set-up-quicklisp ()
  (let ((p (merge-pathnames "setup.lisp" *quicklisp-base-pathname*)))
    (when (probe-file p)
      (format t "~%Loading Quicklisp setup file: ~a ... " p)
      (load p)
      (format t "DONE.~%"))))

(defun set-up-quicklisp-if-needed ()
  (when (not (quicklisp-set-up-p))
    (set-up-quicklisp)))

(set-up-quicklisp-if-needed)



(defun determine-repos-pathname (&optional load-pathname?)
  (let ((load-pathname (or load-pathname? *load-pathname*)))
    (unless load-pathname
      (error "This must be called when there is a load pathname."))
    (let ((up-one (merge-pathnames "../" (enough-namestring load-pathname "load.lisp"))))
      (unless (probe-file up-one)
        (error "The directory up one, ~s, apparently does not exist."
               (namestring up-one)))
      up-one)))
      


(defparameter *repos-namestring*        ; orig: "~/Desktop/Emotiq"
  (namestring (determine-repos-pathname))
  "This is pathname of a directory of repositories, i.e., with
  dbm-git-repo/ as a subdirectory.")

(setf (logical-pathname-translations "PROJECTS")
      `(("LIB;**;"             "/usr/local/lib/**/")
        ("DYLIB64;**;"         "/usr/local/lib64/**/")
        ("LISPLIB;**;"         "/usr/local/Lisp/Source/**/")
        ("LISP;**;" "PROJECTS:dbm-git-repo;**;")
        ("**;" ,(concatenate 'string *repos-namestring* "/**/"))))

(defparameter *projects-lisp-path*
  (translate-logical-pathname "PROJECTS:LISP;"))


#-lispworks
(defun change-directory (to &optional quiet)
  (unless quiet
    (format t "~%Changing directory to projects lisp path: ~s ... ~%" to))
  #-(or allegro ccl)
  (cerror "Continue regardless" "Cannot change dir to: ~s" to)
  (#+allegro chdir #+ccl cwd to))

#+lispworks
(defun current-directory ()
  (get-working-directory))

(change-directory *projects-lisp-path*)

(setf *default-pathname-defaults* (current-directory))


(ql:quickload :asdf)


(load "ASDF-Starter.lisp")

;; To load, generally, now do:
;;
;;   (asdf :cosi)

