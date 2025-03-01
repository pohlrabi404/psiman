;;; psiman.el --- A package manager for Emacs -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Pohlrabi
;;
;; Author: Pohlrabi <pohl@nowhere>
;; Maintainer: Pohlrabi <pohl@nowhere>
;; Created: February 28, 2025
;; Modified: February 28, 2025
;; Version: 0.0.1
;; Homepage: https://github.com/pohlrabi404/psiman
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;; This package provides a simple way to manage system packages from within Emacs.
;; It uses a declarative approach to manage packages by defining a list of desired
;; packages in a file and synchronizing the system packages with this list.
;;
;; While the main purpose is to use it with package managers like pacman, this plugin can
;; also be used to manage symlinks or services if provided with a way to do and undo something
;;
;; It's advised to put the path in version control and NOT put cache in version control
;;; Code:
(defcustom psiman-cmd-list
  ;; Default value
  '(("pacman -S --noconfirm %s"
     "pacman -S --noconfirm %s"
     "~/.dotfiles/.pacman-path"
     "~/.config/.pacman-cache"
     " ")

    ("paru -S --noconfirm %s"
     "paru -R --noconfirm %s"
     "~/.dotfiles/.pkg-path"
     "~/.config/.pkg-cache"
     " "))  ;; concat items with space
  "A list of commands and paths for package management."
  :type 'list
  :group 'psiman)

(defcustom psiman-buffer-name
  ;; Default value
  "*psishell*"
  "Shell buffer name for psiman"
  :type 'string
  :group 'psiman)

;; Synchronize system packages with the declared list.
(defun psiman-sync ()
  "Synchronize system packages with the declared list.
This function iterates over the commands in `psiman-cmd-list` and calls
`psiman-sync-cmd` for each set of commands."
  (interactive)
  (let ((temp "")
        ;; Function to send a command to the shell.
        (send-cmd-to-shell (lambda (cmd buffer-name)
                             "Send a command to the shell.
Arguments:
- cmd: The command to send.
- buffer-name: The name of the buffer to use for the shell."
                             (let ((buffer (get-buffer-create buffer-name)))
                               (switch-to-buffer buffer)
                               (unless (eq major-mode 'shell-mode)
                                 (shell buffer))
                               (insert cmd)
                               (comint-send-input)))))
    (dolist (cmds psiman-cmd-list)
      (setq cmd (apply 'psiman-sync-cmd cmds))
      (if cmd
          (if (eq temp "")
              (setq temp (format "%s" cmd))
            (setq temp (format "%s;%s" temp cmd)))))
    (unless (eq temp "")
      (funcall send-cmd-to-shell temp psiman-buffer-name))))

;; Synchronize system packages with the declared list for a specific set of commands.
(defun psiman-sync-cmd (do-cmd undo-cmd path cache-path group-item)
  "Synchronize system packages with the declared list for a specific set of commands."
  (let* (
         ;; Function to read a file into a list of lines.
         (file-to-list (lambda (path)
                         (unless (file-exists-p path)
                           (with-temp-file path
                             (insert "")))
                         (with-temp-buffer
                           (insert-file-contents path)
                           (split-string (buffer-string) "\n" t))))

         ;; Get the list of new and old items.
         (items-list (funcall file-to-list path))
         (cache-list (funcall file-to-list cache-path))
         (do-list (cl-set-difference items-list cache-list :test #'equal))
         (undo-list (cl-set-difference cache-list items-list :test #'equal))

         ;; Function to create the command string.
         (make-cmd (lambda ()
                     (if group-item
                         (let* ((do-list-str (mapconcat 'identity do-list group-item))
                                (undo-list-str (mapconcat 'identity undo-list group-item))
                                (do-cmd (format do-cmd do-list-str))
                                (undo-cmd (format undo-cmd undo-list-str)))
                           (if do-list
                               (if undo-list
                                   (format "%s;%s" do-cmd undo-cmd)
                                 (format "%s" do-cmd))
                             (if undo-list
                                 (format "%s" undo-cmd)
                               '())))
                       (let ((temp ""))
                         (dolist (item do-list)
                           (if (eq temp "")
                               (setq temp (format "%s" (format do-cmd item)))
                             (setq temp (format "%s;%s" temp (format do-cmd item)))))
                         (dolist (item undo-list)
                           (if (eq temp "")
                               (setq temp (format "%s" (format undo-cmd item)))
                             (setq temp (format "%s;%s" temp (format undo-cmd item)))))
                         (if (eq temp "")
                             nil
                           (format "%s" temp)))))))
    (setq cmd nil)
    (if (funcall make-cmd)
        (setq cmd (format "%s; %s" (funcall make-cmd) (format "cp %s %s" path cache-path))))
    cmd))

(provide 'psiman)
;;; psiman.el ends here
