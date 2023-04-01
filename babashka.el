;;; babashka.el --- Utilities for working with babashka -*- lexical-binding: t -*-

;; Copyright (c) 2023 Daniel Kraus <daniel@kraus.my>

;; Author: Daniel Kraus <daniel@kraus.my>
;; URL: https://github.com/dakra/babashka.el
;; Keywords: convenience, tools, processes, babashka, bb, nbb, clojure
;; Version: 0.1
;; Package-Requires: ((emacs "26") (parseedn "1.0.6"))
;; SPDX-License-Identifier: GPL-3.0-or-later

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; `babashka.el' provides utilities for working with the babashka.

;;; Code:

(require 'parseedn)


;;; Customization

(defgroup babashka nil
  "Utilities for babashka."
  :prefix "babashka-"
  :group 'tools)

(defcustom babashka-keymap-prefix (kbd "C-c '")
  "Babashka keymap prefix."
  :type 'key-sequence)

(defcustom babashka-default-task nil
  "Default task suggestion for `babashka-tasks-run'."
  :type 'string
  :safe #'stringp)
;;;###autoload(put 'babashka-settings 'safe-local-variable #'stringp)

(defcustom babashka-project-root nil
  "Root of the babashka project.
When NIL it uses the path that contains the =bb.edn= file."
  :type 'directory
  :safe #'directory-name-p)
;;;###autoload(put 'babashka-project-root 'safe-local-variable #'directory-name-p)


;;; Variables

(defvar babashka-tasks-run-history nil
  "Completion history for `babashka-tasks-run'.")


;;; Private helper functions

(defun babashka--project-root ()
  "Calculate project root."
  (or babashka-project-root
      (locate-dominating-file default-directory "bb.edn")))

(defun babashka--read-project-file ()
  "Return filename of =bb.edn=."
  (let* ((bb.edn (expand-file-name "bb.edn" (babashka--project-root)))
         (content (with-temp-buffer
                    (insert-file-contents bb.edn)
                    (buffer-string))))
    (parseedn-read-str content)))

(defun babashka-tasks-list ()
  "Return a list of tasks defined in =bb.edn=."
  (thread-last (babashka--read-project-file)
               (gethash :tasks)
               hash-table-keys
               (delete :requires)))

(defun babashka--read-task ()
  "Prompt user for a task."
  (completing-read "Run babashka task: "
                   (babashka-tasks-list)
                   nil t
                   babashka-default-task
                   babashka-tasks-run-history))


;;; Public functions

;;;###autoload
(defun babashka-tasks-run (task &optional args comint)
  "Run a babashka TASK with command line ARGS.
If called with a prefix argument, read ARGS from minibuffer.  If
optional third arg COMINT is t, or if the command was invoked
with 2 prefix arguments (C-u C-u), the buffer will be in Comint
mode with `compilation-shell-minor-mode'."
  (interactive
   (list
    (babashka--read-task)
    (if current-prefix-arg
        (read-from-minibuffer "Task arguments: ")
      "")
    (consp (equal current-prefix-arg '(16)))))
  (let ((default-directory (babashka--project-root))
        (cmd (concat "bb " (shell-quote-argument task) " " args)))
    (compilation-start cmd comint (lambda (_mode) (format "*babashka task: %s*" task)))))

;;;###autoload
(defun babashka-find-project-file ()
  "Open =bb.edn= file."
  (interactive)
  (find-file (expand-file-name "bb.edn" (babashka--project-root))))

;;;###autoload
(defun babashka-find-project-file-other-window ()
  "Open =bb.edn= file in other window."
  (interactive)
  (find-file-other-window (expand-file-name "bb.edn" (babashka--project-root))))


;;; babashka-mode

(defvar babashka-command-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "r") 'babashka-tasks-run)
    (define-key map (kbd "p") 'babashka-find-project-file)
    (define-key map (kbd "4 p") 'babashka-find-project-file-other-window)
    map))

(defvar babashka-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map babashka-keymap-prefix babashka-command-map)
    map))

(easy-menu-define babashka-mode-menu babashka-mode-map
  "Menu for working with babashka projects."
  '("Babashka"
    ["Run task" babashka-tasks-run
     :help "Run a babashka task"]
    ["Find project file" babashka-find-project-file
     :help "Find project file (bb.edn)."]))

;;;###autoload
(define-minor-mode babashka-mode
  "Minor mode to interact with babashka projects.

\\{babashka-mode-map}"
  :lighter " babashka"
  :keymap babashka-mode-map)

;;;###autoload
(define-globalized-minor-mode global-babashka-mode babashka-mode
  (lambda ()
    (ignore-errors
      (when (babashka--project-root)
        (babashka-mode))))
  :require 'babashka)

(provide 'babashka)
;;; babashka.el ends here
