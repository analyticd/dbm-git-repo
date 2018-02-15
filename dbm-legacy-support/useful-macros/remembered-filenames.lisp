;; remembered-filenames.lispp -- convenience macros for remembering
;; prompted filenames
;;
;; DM/RAL 11/10
;; -------------------------------------------------------------
#|
The MIT License

Copyright (c) 2017-2018 Refined Audiometrics Laboratory, LLC

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
|#

(in-package :um.remfn)

;; ----------------------------------------------------------

(defvar *remembered-filenames*
  (make-hash-table))

(defun remember-filename (key fname)
  (setf (gethash key *remembered-filenames*) fname))

(defun remembered-filename (key)
  (gethash key *remembered-filenames*))

(defun do-with-remembered-filename (key init prompter fn)
  (um:when-let (fname (or init (funcall prompter (remembered-filename key))))
    (remember-filename key fname)
    (funcall fn fname)))
  
(defmacro with-remembered-filename ((fname key &optional init) form &body body)
  `(do-with-remembered-filename ,key ,init
                                (lambda (,fname)
                                  (declare (ignorable ,fname))
                                  ,form)
                                (lambda (,fname)
                                  (declare (ignorable ,fname))
                                  ,@body)))

#+:LISPWORKS
(editor:setup-indent "with-remembered-filename" 1)

(defmacro with-remembered-prompting ((fname key
                                            &optional init
                                            (prompt "Pick a file")
                                            &rest
                                            prompt-keys)
                                     &body body)
  `(with-remembered-filename (,fname ,key ,init)
       (multiple-value-call #'capi:prompt-for-file ,prompt
         (values ,@prompt-keys)
         :pathname ,fname
         :filter   "*.*")
     ,@body))
                                     
#+:LISPWORKS
(editor:setup-indent "with-remembered-prompting" 1)


;; ----------------------------------------------------------

(defvar *last-timestamp* nil)
(defvar *timestamp-index* 0)

(defun filename-timestamp-string ()
  (let ((now (get-universal-time)))
    (unless (eql now *last-timestamp*)
      (setf *last-timestamp*  now
            *timestamp-index* 0))
    (multiple-value-bind (ss mm hh dd mon yr)
        (decode-universal-time now 0)
      (format nil "~A~{~{~2,'0d~}-~}~d"
              yr (list
                  (list mon dd)
                  (list hh mm ss))
              (incf *timestamp-index*)))))

(defun add-timestamp-to-filename (fname)
  (concatenate 'string
               (pathname-name fname)
               "-"
               (filename-timestamp-string)
               "."
               (pathname-type fname)))
