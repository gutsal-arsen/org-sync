;;; os-bb.el --- Bitbucket backend for org-sync.

;; Copyright (C) 2012  Aurelien Aptel
;;
;; Author: Aurelien Aptel <aurelien dot aptel at gmail dot com>
;; Keywords: org, bitbucket, synchronization
;; Homepage: http://orgmode.org/worg/org-contrib/gsoc2012/student-projects/org-sync
;;
;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; This file is not part of GNU Emacs.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This package implements a backend for org-sync to synchnonize
;; issues from a bitbucket repo with an org-mode buffer.

;;; Code:

(eval-when-compile (require 'cl))
(require 'org-sync)
(require 'url)

(defvar url-http-end-of-headers)

(defvar os-bb-auth nil
  "Bitbucket login (\"user\" . \"pwd\")")

(defun os-bb-request (method url &optional data)
  "Send HTTP request at URL using METHOD with DATA.
AUTH is a cons (\"user\" . \"pwd\"). Return the server
decoded response in JSON."
  (let* ((url-request-method method)
         (url-request-data data)
         (auth os-bb-auth)
         (buf)
         (url-request-extra-headers
          (unless data
            '(("Content-Type" . "application/x-www-form-urlencoded")))))

    (if (consp auth)
        ;; dynamically bind auth related vars
        (let* ((str (concat (car auth) ":" (cdr auth)))
               (encoded (base64-encode-string str))
               (login `(("api.bitbucket.org:443" ("Bitbucket API" . ,encoded))))
               (url-basic-auth-storage 'login))
          (setq buf (url-retrieve-synchronously url)))
      ;; nothing more to bind
      (setq buf (url-retrieve-synchronously url)))
    (with-current-buffer buf
      (goto-char url-http-end-of-headers)
      (prog1 (json-read) (kill-buffer)))))

;; override
(defun os-bb-base-url (url)
  "Return base URL."
  (cond
   ;; web ui url
  ((string-match "^\\(?:https?://\\)?\\(?:www\\.\\)?bitbucket.org/\\([^/]+\\)/\\([^/]+\\)/?$" url)
   (concat "https://api.bitbucket.org/1.0/repositories/"
           (match-string 1 url) "/" (match-string 2 url)))

  ;; api url
  ((string-match "api.bitbucket.org/1.0/repositories" url)
   url)))


;; From https://confluence.atlassian.com/display/BITBUCKET/Issues

;;     title: The title of the new issue.
;;     content: The content of the new issue.
;;     component: The component associated with the issue.
;;     milestone: The milestone associated with the issue.
;;     version: The version associated with the issue.
;;     responsible: The username of the person responsible for the issue.

;;     priority: The priority of the issue. Valid priorities are:
;;     - trivial
;;     - minor
;;     - major
;;     - critical
;;     - blocker

;;     status: The status of the issue. Valid statuses are:
;;     - new
;;     - open
;;     - resolved
;;     - on hold
;;     - invalid
;;     - duplicate
;;     - wontfix

;;     kind: The kind of issue. Valid kinds are:
;;     - bug
;;     - enhancement
;;     - proposal
;;     - task

(defconst os-bb-priority-list
  '("trivial" "minor" "major" "critical" "blocker")
  "List of valid priority for a bitbucket issue.")

(defconst os-bb-status-list
  '("new" "open" "resolved" "on hold" "invalid" "duplicate" "wontfix")
  "List of valid status for a bitbucket issue.")

(defconst os-bb-kind-list
  '("bug" "enhancement" "proposal" "task")
  "List of valid kind for a bitbucket issue.")

(defun os-bb-bug-to-form (bug)
  "Return BUG as an form alist."
  (let* ((priority (os-get-prop :priority bug))
         (title (os-get-prop :title bug))
         (desc (os-get-prop :desc bug))
         (assignee (os-get-prop :assignee bug))
         (status (if (eq (os-get-prop :status bug) 'open) "open" "resolved"))
         (kind (os-get-prop :kind bug)))

    (if (and priority (not (member priority os-bb-priority-list)))
      (error "Invalid priority \"%s\" at bug \"%s\"." priority title))

    (if (and kind (not (member kind os-bb-kind-list)))
      (error "Invalid kind \"%s\" at bug \"%s\"." kind title))

    (remove-if (lambda (x)
                 (null (cdr x)))
               `(("title"       . ,title)
                 ("status"      . ,status)
                 ("content"     . ,desc)
                 ("responsible" . ,assignee)
                 ("priority"    . ,priority)
                 ("kind"        . ,kind)))))

(defun os-bb-post-encode (args)
  "Return form alist ARGS as a url-encoded string."
  (mapconcat (lambda (arg)
               (concat (url-hexify-string (car arg))
                       "="
                       (url-hexify-string (cdr arg))))
             args "&"))

(defun os-bb-repo-name (url)
  "Return repo name at URL."
  (when (string-match "api\\.bitbucket.org/1\\.0/repositories/\\([^/]+\\)/\\([^/]+\\)" url)
    (match-string 2 url)))

(defun os-bb-repo-user (url)
  "Return repo username at URL."
  (when (string-match "api\\.bitbucket.org/1\\.0/repositories/\\([^/]+\\)/\\([^/]+\\)" url)
    (match-string 1 url)))

;; override
(defun os-bb-fetch-buglist (last-update)
  "Return the buglist at os-base-url."
  (let* ((url (concat os-base-url "/issues"))
         (json (os-bb-request "GET" url))
         (title (concat "Bugs of " (os-bb-repo-name url))))

    `(:title ,title
             :url ,os-base-url
             :bugs ,(mapcar 'os-bb-json-to-bug (cdr (assoc 'issues json))))))


(defun os-bb-json-to-bug (json)
  "Return JSON as a bug."
  (flet ((va (key alist) (cdr (assoc key alist)))
         (v (key) (va key json)))
    (let* ((id (v 'local_id))
           (metadata (v 'metadata))
           (kind (va 'kind metadata))
           (version (va 'version metadata))
           (component (va 'component metadata))
           (milestone (va 'milestone metadata))
           (author (va 'username (v 'reported_by)))
           (assignee (va 'username (v 'responsible)))
           (txtstatus (v 'status))
           (status (if (or (string= txtstatus "open")
                           (string= txtstatus "new"))
                       'open
                     'closed))
           (priority (v 'priority))
           (title (v 'title))
           (desc (v 'content))
           (ctime (os-parse-date (v 'utc_created_on)))
           (mtime (os-parse-date (v 'utc_last_updated))))

      `(:id ,id
            :priority ,priority
            :assignee ,assignee
            :status ,status
            :title ,title
            :desc ,desc
            :date-creation ,ctime
            :date-modification ,mtime
            :kind ,kind
            :version ,version
            :component ,component
            :milestone ,milestone))))

;; override
(defun os-bb-send-buglist (buglist)
  "Send a BUGLIST on the bugtracker and return an updated buglist."
  (let* ((new-url (concat os-base-url "/issues"))
         (new-bugs
          (mapcar (lambda (b)
                    (let* ((sync (os-get-prop :sync b))
                           (id (os-get-prop :id b))
                           (data (os-bb-post-encode (os-bb-bug-to-form b)))
                           (modif-url (format "%s/%d/" new-url id))
                           (result
                            (cond
                             ;; new bug
                             ((eq sync 'new)
                              (os-bb-request "POST" new-url data))

                             ;; delete bug
                             ((eq sync 'delete)
                              (os-bb-request "DELETE" modif-url))

                             ;; update bug
                             ((eq sync 'change)
                              (os-bb-request "PUT" modif-url data)))))

                      (cond
                       ;; if bug was :sync same, return it
                       ((null result)
                        b)

                       ;; else, result is the updated bug
                       (t
                        (os-bb-json-to-bug result)))))
                  (os-get-prop :bugs buglist))))

    `(:title ,(os-get-prop :title buglist)
             :url ,os-base-url
             :bugs ,new-bugs)))

;;; os-bb.el ends here