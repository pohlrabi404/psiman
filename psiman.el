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

;; Define a customizable list of commands and paths for package management.
(defcustom psiman-cmd-list
  ;; Default value
  '(("paru -S --noconfirm %s" ;; install command
     "paru -R --noconfirm %s" ;; uninstall command
     "~/.dotfiles/.pkg-path"              ;; pkgs path
     "~/.config/.pkg-cache"             ;; cache path
     " "))  ;; concat items with space
  "A list of commands and paths for package management.
Each sublist contains:
- Install command
- Uninstall command
- Path to the package list file
- Path to the cache file
- Group item (used for grouping items together, put nil in if not needed and each items will have their own command)"
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
  "Synchronize system packages with the declared list for a specific set of commands.
This function reads the package list from the file at `path`, compares it with the
cache file at `cache-path`, and installs or uninstalls packages as necessary.
Arguments:
- do-cmd: The command to install packages.
- undo-cmd: The command to uninstall packages.
- path: The path to the package list file.
- cache-path: The path to the cache file.
- group-item: used for grouping items together, nil if you want to separate each commands"
  (let* (
         ;; Function to read a file into a list of lines.
         (file-to-list (lambda (path)
                         "Read a file into a list of lines.
If the file does not exist, create an empty file at the specified path."
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
                     "Create the command string.
If `group-item` is non-nil, group the commands together. Otherwise, create a
separate command for each item."
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
        (setq cmd (format "%s; %s" (funcall make-cmd) (format "cp %s %s;" path cache-path))))
    cmd
    ))

(provide 'psiman)
;;; psiman.el ends here
