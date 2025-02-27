;;; psiman.el --- A package manager for Orgmode  -*- lexical-binding: t; -*-
;;
;; Copyright (C) 2025 Pohlrabi
;;
;; Author: Pohlrabi <pohl@nowhere>
;; Maintainer: Pohlrabi <pohl@nowhere>
;; Created: February 28, 2025
;; Modified: February 28, 2025
;; Version: 0.0.1
;; Homepage: https://github.com/pohl/pepsiman
;; Package-Requires: ((emacs "24.3"))
;;
;; This file is not part of GNU Emacs.
;;
;;; Commentary:
;;
;; Pohl's Package Manager (psiman) is a simple Emacs package designed to manage
;; system packages using a declarative approach. It allows you to define a list
;; of packages in a file and synchronizes the system packages with this list by
;; installing missing packages and uninstalling packages that are no longer in
;; the list.
;;
;; Features:
;; - Declarative Package Management: Define your desired package list in a file.
;; - Automatic Installation and Uninstallation: Synchronize your system packages
;;   with the declared list.
;; - Cache Management: Maintain a cache to track installed packages.
;;
;; Installation:
;; 1. Clone the repository:
;;    git clone https://github.com/pohlrabi404/pepsiman.git
;; 2. Load the package:
;;    Add the following to your Emacs configuration file (`.emacs` or `init.el`):
;;    (add-to-list 'load-path "/path/to/pepsiman")
;;    (require 'psiman)
;;
;; Usage:
;; 1. Define Package List:
;;    Create a file at the path specified by `psiman-pkgs-path` (default: `./pkgs`).
;;    Each line in this file should contain a package name. For example:
;;    ```
;;    vim
;;    neovim
;;    zsh
;;    ```
;; 2. Synchronize Packages:
;;    Run the following command to synchronize your system packages with the
;;    declared list:
;;    M-x psiman-sync-all
;;
;; Configuration:
;; You can customize the behavior of `psiman` by setting the following variables:
;; - `psiman-pkgs-path`: The path to the file containing the list of packages.
;;   Default: `./pkgs`
;; - `psiman-cache-path`: The path to the cache file.
;;   Default: `./cache`
;; - `psiman-install-cmd`: The command to install packages.
;;   Default: `"paru -S "`
;; - `psiman-uninstall-cmd`: The command to uninstall packages.
;;   Default: `"paru -R "`
;;
;;; Code:

(defcustom psiman-pkgs-path "~/.pkgs"
  "Package list path, psiman will use this to compare with cache."
  :type 'string
  :group 'psiman)

(defcustom psiman-cache-path "~/.cache"
  "Cache path, psiman will use this to compare with packages list."
  :type 'string
  :group 'psiman)

(defcustom psiman-install-cmd "paru -S "
  "Install command."
  :type 'string
  :group 'psiman)

(defcustom psiman-uninstall-cmd "paru -R "
  "Uninstall command."
  :type 'string
  :group 'psiman)

(defcustom psiman-buffer-name "*Pohl's Package Manager*"
  "Name of the package installer buffer."
  :type 'string
  :group 'psiman)

(defun psiman-read-file-content (filepath)
  "Read the content of a file at FILEPATH and return it as a list of strings.
If the file does not exist, create an empty file at the specified FILEPATH."
  (with-temp-buffer
    (unless (file-exists-p filepath)
      (with-temp-file filepath
        (insert "")))
    (insert-file-contents filepath)
    (split-string (buffer-string) "\n" t)))

(defun psiman-concat-list (list)
  "Concatenate a LIST of strings into a single string with spaces as separators."
  (mapconcat 'identity list " "))

(defun psiman-send-cmd (command)
  "Send a COMMAND to the shell buffer.
If the buffer does not exist, create it and switch to shell mode."
  (let ((buffer (get-buffer-create psiman-buffer-name)))
    (switch-to-buffer buffer)
    (unless (eq major-mode 'shell-mode)
      (shell buffer))
    (insert command)
    (comint-send-input)))

(defun psiman-get-install-list ()
  "Get a list of packages to install based on the difference between the package list and the cache."
  (let ((pkgs (psiman-read-file-content psiman-pkgs-path))
        (cache (psiman-read-file-content psiman-cache-path)))
    (psiman-concat-list (cl-set-difference pkgs cache :test #'equal))))

(defun psiman-get-uninstall-list ()
  "Get a list of packages to uninstall based on the difference between the cache and the package list."
  (let ((pkgs (psiman-read-file-content psiman-pkgs-path))
        (cache (psiman-read-file-content psiman-cache-path)))
    (psiman-concat-list (cl-set-difference cache pkgs :test #'equal))))

(defun psiman-do-install ()
  "Install packages that are in the package list but not in the cache."
  (unless (s-blank-p (psiman-get-install-list))
    (psiman-send-cmd (format "%s %s" psiman-install-cmd (psiman-get-install-list)))))

(defun psiman-do-uninstall ()
  "Uninstall packages that are in the cache but not in the package list."
  (unless (s-blank-p (psiman-get-uninstall-list))
    (psiman-send-cmd (format "%s %s" psiman-uninstall-cmd (psiman-get-uninstall-list)))))

(defun psiman-sync-cache ()
  "Update the cache file with the current package list."
  (let ((contents (with-temp-buffer
                   (insert-file-contents psiman-pkgs-path)
                   (buffer-string))))
    (with-temp-file psiman-cache-path
      (insert contents))))

(defun psiman-sync-all ()
  "Synchronize the system packages with the declared list by installing and uninstalling packages as needed."
  (interactive)
  (psiman-do-install)
  (psiman-do-uninstall)
  (psiman-sync-cache))

(provide 'psiman)
;;; psiman.el ends here
