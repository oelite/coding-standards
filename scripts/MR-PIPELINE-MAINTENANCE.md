# Dedicated merge-request pipeline creation

`oelite-gitlab.sh mr-pipeline-create <project-path> <mr-iid> <agent>` creates a detached
merge-request pipeline through GitLab's dedicated MR endpoint. It is not a branch
pipeline and is not a server-side stale-ref repair operation.

## Preconditions and evidence

- Explicit agent identity, open MR, same source/target project, trusted project SSH URL.
- Read access to the Git remote through the existing SSH agent. No PAT is placed in a Git URL.
- Source branch ref, advertised `refs/merge-requests/<iid>/head`, API `sha`, and
  `diff_refs.head_sha` must all agree. Unknown, missing or inconsistent values fail closed.
- The command performs exactly one creation request, reports ID/SHA/ref/source/status/URL,
  validates detached `merge_request_event` evidence, and rechecks Git/API heads afterward.
- Merged-results pipelines are deliberately unsupported: their synthetic SHA needs a
  separate reviewed evidence policy. A created pipeline may exist even if response or
  post-create validation fails; inspect it before invoking the command again.
- There is no atomic SHA guard on this endpoint. A concurrent push can create a pipeline
  that this command rejects as stale. A successful command means creation and bounded
  head consistency, **not** successful CI, reviewer approval, or permission to merge.

The operation does not alter branches, drafts, titles, approvals, CI rules or history.
Never retry superseded jobs or push empty commits to manufacture current-head evidence.
HTTP failures report status/body without automatic retries, using the wrapper transport.

## Stale metadata diagnosis

If refs disagree, stop before pipeline creation. Record the project ID, branch, source
SHA, MR Git ref SHA, API SHA, diff head and observation time through approved wrapper
reads and `git ls-remote`. Recheck to distinguish an eventual update from a persistent
failure. Do not assert a Sidekiq failure solely from a stale diff or `created` pipeline.

An authorized GitLab administrator should inspect, read-only first:

1. GitLab version and deployment topology, Gitaly, Rails and Sidekiq service health.
2. Queue backlog/latency, process heartbeat, retry/dead counts, and worker routing.
3. Filtered post-receive/Sidekiq logs correlated by project ID and affected push time;
   report only worker class, timestamps, job/correlation IDs, exception class and a
   sanitized reason, never raw payloads, credentials or full unfiltered logs.
4. Whether the push reached `PostReceive` and downstream MR refresh processing, and
   whether pipeline processing is separately delayed.

Access must use the documented operator maintenance channel. The local cluster helper
requires operator-distributed kubeconfigs; absent files are not permission to seek
credentials in chat or substitute an undocumented host. No restart, job deletion,
internal post-receive call or broad replay is authorized by this command. Propose a
narrow fix based on evidence and obtain the required authorization before mutation.

## References and verification

- GitLab MR API: https://docs.gitlab.com/api/merge_requests/#create-merge-request-pipeline
- PostReceive flow: https://docs.gitlab.com/development/internal_api/#postreceive
- Queue metrics: https://docs.gitlab.com/api/sidekiq_metrics/

Run `zsh -n scripts/oelite-gitlab.sh` and
`python3 -m unittest discover -s tests/regression -p 'test_mr_pipeline*.py' -v`.
The latter tests pure validation and isolated command transport behavior; they do not
claim live GitLab integration or persistence coverage. Validate the reviewed command
against an authorized stable consumer only after head agreement and normal review.
