(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(debian-changelog-full-name "Christopher Hoover")
 '(debian-changelog-mailing-address "ch@murgatroid.com")
 '(inhibit-startup-screen t)
 '(package-selected-packages '(cargo-mode rust-mode go-mode))
 '(rust-format-on-save t)
 '(hexl-bits 8))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(default ((t (:family "Ubuntu Mono" :foundry "DAMA" :slant normal :weight normal :height 203 :width normal)))))


(add-hook 'rust-mode-hook
          (lambda () (setq indent-tabs-mode nil)))
(add-hook 'rust-mode-hook 'cargo-minor-mode)

(put 'downcase-region 'disabled nil)

(defun del-binary_characters (beg end)
  "Delete non-ascii characters in a region"
  (interactive "r")
  (save-excursion
    (save-restriction
      (narrow-to-region beg end)
      (goto-char (point-min))
      (while (re-search-forward "[^[:ascii:]]" nil t)
        (replace-match "")))))
