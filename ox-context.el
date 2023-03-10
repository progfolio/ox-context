;;; ox-context.el --- Contextual org export preambles.  -*- lexical-binding: t; -*-

;; Copyright (C) 2023  Nicholas Vollmer

;; Author:  Nicholas Vollmer
;; Keywords: convenience

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Code:
(require 'ox)

(defcustom ox-contexts nil
  "Alist of form: ((BACKEND . FUNCTIONS)...).
BACKEND is the symbol name of an export backend.
FUNCTIONS is a list of contextual export snippet functions.
See `ox-context-def' for the requirements of each function.
Results are cached in the symbol `ox-context' for the duration of the export."
  :type 'alist
  :group 'org)

(defvar ox-context nil "`ox-context-get' symbol cache of form: ((SYM . VAL)...).")
(defvar ox-context--conditions '(and or not))

(defun ox-context-get (sym info)
  "Return contextual value for SYM.
If SYM's is being accessed for the first time, cache its value in the context.
INFO is the current export info plist."
  (if-let ((cached (assq sym ox-context)))
      (cdr cached)
    (let ((val (if (functionp sym) (funcall sym info) sym)))
      (push (cons sym val) ox-context)
      val)))

(defun ox-context (backend info)
  "Return current export BACKEND context.
INFO is the current export data."
  (let ((ox-context nil))
    (mapc (lambda (fn) (ox-context-get fn info)) (alist-get backend ox-contexts))
    ox-context))

(defun ox-context-snippet-p (object)
  "Return t if OBJECT is a contextual export snippet."
  (or (stringp object) (stringp (car-safe object))))

(defun ox-context-preamble (context)
  "Return preamble string from CONTEXT."
  (mapcar #'cdr (cl-remove-if-not #'ox-context-snippet-p context :key #'cdr)))

(defun ox-context-buffer-match-p (regexp)
  "Return t if current export contents matches REGEXP."
  (string-match-p regexp (buffer-substring-no-properties (point-min) (point-max))))

(defun ox-context-inject (form)
  "Inject context accessors into FORM."
  (if (and form (listp form))
      (cl-loop for el in form collect (ox-context-inject el))
    (if (memq form ox-context--conditions) form `(ox-context-get ',form info))))

(defmacro ox-context-requires (conds &rest body)
  "Execute BODY when CONDS non-nil.
CONDS is a list of function and or variable symbols.
The conditions `and', `or', and `not' may be used to logically group CONDS."
  (declare (indent 1) (debug t))
  (let ((condition (car (memq (car conds) ox-context--conditions))))
    `(when (,(or condition 'and) ,@(ox-context-inject (if condition (cdr conds) conds)))
       ,@body)))

(defun ox-context-prevent (sym)
  "Nullify SYM in context cache."
  (setf (alist-get sym ox-context) nil))

(cl-defmacro ox-context-def (name (&key requires prevents docstring) &rest body)
  "Define a contextual export snippet function.
NAME is a symbol which other contextual snippets may refer to.
The accepted keyword arguments are:
  :docstring
    A description of the snippet
    e.g. \"My snippet\"
  :requires
    A symbol or list of symbols
    Each symbol is either the name of: a contextual export snippet,
    a function, or a variable. Symbols may be logically grouped by
    `and', `or', and `not'.
    e.g. (and snippet-a (not (or snippet-b snippet-c)))

    Each symbol is checked for in the current export context.
    If the :requires condition returns non-nil, BODY is executed.
  :prevents
    A symbol or list of symbols.
    Each symbol is has its value removed from the current export context.
    e.g. (removed-snippet removed-variable ignored-function)

In order to include a snippet in the export, BODY must return either:
A string, or a list of form (STRING . PROPS)."
  (declare (indent defun) (debug t))
  `(defun ,name (info)
     ,(or docstring "Generated by `ox-context-def'.")
     ,@(when prevents
         `((mapc #'ox-context-prevent ',(if (listp prevents) prevents (list prevents)))))
     ,@(if requires
         `((ox-context-requires ,(if (listp requires) requires (list requires)) ,@body))
         body)))

(provide 'ox-context)
;;; ox-context.el ends here
