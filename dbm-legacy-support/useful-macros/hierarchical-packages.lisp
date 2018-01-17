;; Hierarchical package names

(in-package #:useful-macros)

;; ------------------------------------------------------------

(defun package-relative-name (name)
  ;; Given a package name, a string, do a relative package name lookup.
  ;;
  ;; It is intended that this function will be called from find-package.
  ;; In Allegro, find-package calls package-name-to-package, and the latter
  ;; function calls this function when it does not find the package.
  ;;
  ;; Because this function is called via the reader, we want it to be as
  ;; fast as possible.
  ;;
  (declare (optimize speed))
  (let ((name (if (packagep name)
                  (package-name name)
                (string name))))
    (declare (type string name))
    
    (flet ((relative-to (package name)
             (declare (type string package name))
             (if (string= "" name)
                 package
               (concatenate 'simple-string
                            package "." name)))
           
           (find-non-dot (name)
             (declare (type string name))
             (or
              (position #\. name :test #'char/=)
              (length name))))
      
      (if (char= #\. (char name 0))
          (let* ((n-dots (find-non-dot name))
                 (p      (package-name *package*))
                 (plen   (length p))
                 (end    plen))
            (declare (type fixnum n-dots plen end)
                     (type string p))
            (loop repeat (the fixnum (1- n-dots)) do
                  (setf end (or (position #\. p
                                          :test #'char=
                                          :from-end t
                                          :end  end)
                                end)))
            (relative-to (if (= end plen)
                             p
                           (subseq p 0 end))
                         (subseq name n-dots)))
        ;; else
        name))))

;; ----------------------------------------------------------
;; cl:find-package -- allows package relative hierarchical names

#+:LISPWORKS
(lw:defadvice (cl:find-package :hierarchical-packages :around)
    (name/package)
    (declare (optimize speed))          ;this is critical code
    (or (lw:call-next-advice name/package)
        (lw:call-next-advice
         (package-relative-name name/package)) ))

;; ----------------------------------------------------------
;; editor::pathetic-parse-symbol -- allow symbol completion to
;; use heirarchical package names
;;
;; By the time editor::pathetic-parse-symbol is called, the value
;; of *PACKAGE* will have been reset (incorrectly?) to COMMON-LISP-USER,
;; and does not accurately reflect where the user is operating. The DEFAULT-PACKAGE
;; argument appears to correctly reflect the user's context.
;;
;; dm/ral 04/16

#+:LISPWORKS
(lw:defadvice (editor::pathetic-parse-symbol :hierarchical-packages :around)
    (symbol default-package &optional (errorp t))
  (let ((*package* default-package))
    ;; (format t "default-package = ~S" default-package)
    (lw:call-next-advice symbol default-package errorp)))

;; -------------------------------------------------------
;; sys::find-package-without-lod -- used by LW tools
;; this primitive is actually called by FIND-PACKAGE,
;; and so it will override any actions in the advice on FIND-PACKAGE.

#+:LISPWORKS
(lw:defadvice (sys::find-package-without-lod :hierarchical-packages :around)
    (name)
  ;; used by editor to set buffer package
  (declare (optimize speed))
  ;; (format t "find-package-without-lod: ~S" (editor:variable-value 'editor::current-package) )
  (or (lw:call-next-advice)
      (lw:call-next-advice (package-relative-name name))))

;; ------------------------------------------------------------
;; cdp

(defmacro cdp (name)
  ;; change package with package-relative name
  `(in-package ,(package-relative-name name)))

(export 'cdp)

