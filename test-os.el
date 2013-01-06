;;; test-os.el ---

;; Copyright (C) 2013 Grégoire Jadi

;; Author: Grégoire Jadi <gregoire.jadi@gmail.com>

;; This program is free software: you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation, either version 3 of
;; the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;;; Code:

(require 'ert)
(require 'os)

(ert-deftest test-org-sync-headline-url ()
  (should
   (equal
    (with-temp-buffer
      (insert "
:PROPERTIES:
:url: http://foo.bar
:END:")
      (org-mode)
      (org-sync-headline-url
       (org-element-contents
        (org-element-parse-buffer))))
    "http://foo.bar"))

  (should
   (equal
    (with-temp-buffer
      (insert "
* Test
:PROPERTIES:
:url: http://foo.bar
:END:")
      (org-mode)
      (org-sync-headline-url
       (org-element-contents
        (org-element-parse-buffer))))
    "http://foo.bar"))

  (should
   (equal
    (with-temp-buffer
      (insert "
:PROPERTIES:
:dummy: baz
:url: http://foo.bar
:fizz: bar
:END:")
      (org-mode)
      (org-sync-headline-url
       (org-element-contents
        (org-element-parse-buffer))))
    "http://foo.bar"))

  (should
   (equal
    (with-temp-buffer
      (insert "
:PROPERTIES:
:fizz: bar
:END:")
      (org-mode)
      (org-sync-headline-url
       (org-element-contents
        (org-element-parse-buffer))))
    nil)))

(ert-deftest test-org-sync-buglist-headline-p ()
  (should
   (equal
    (with-temp-buffer
      (insert "
* Test
:PROPERTIES:
:url: http://foo.bar
:END:")
      (org-mode)
      (org-sync-buglist-headline-p
       (first
        (org-element-contents
         (org-element-parse-buffer)))))
    t))

  (should
   (equal
    (with-temp-buffer
      (insert "
* Test
:PROPERTIES:
:fizz: bar
:END:")
      (org-mode)
      (org-sync-buglist-headline-p
       (first
        (org-element-contents
         (org-element-parse-buffer)))))
    nil))

  (should
   (equal
    (with-temp-buffer
      (insert "
:PROPERTIES:
:url: foo
:END:")
      (org-mode)
      (org-sync-buglist-headline-p
       (first
        (org-element-contents
         (org-element-parse-buffer)))))
    nil)))

(provide 'test-os)

;;; test-os.el ends here
