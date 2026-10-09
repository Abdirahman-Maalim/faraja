#!/usr/bin/env bash

set -euo pipefail
source "$(dirname "$0")/config.sh"
cd "$ROOT_DIR"

http() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 "$1" || true; }
count() { curl -s "$BACKEND_URL/$1" | python3 -c 'import sys,json;print(len(json.load(sys.stdin)))' 2>/dev/null || echo "?"; }
gauge() { curl -s "$BACKEND_URL/metrics" | grep "^$1 " | awk '{print $2}' | cut -d. -f1; }
rows() { kubectl exec -n "$NAMESPACE" "$DB_POD" -- psql -U "$DB_USER" -d "$DB_NAME" -tAc "select count(*) from $1;" 2>/dev/null || echo "?"; }
ready() { [ "$(http "$BACKEND_URL/health")" = 200 ] || die "backend down. Run: ./scripts/faraja.sh forward"; }

#  forward 
PID_FILE=/tmp/faraja-forward.pids

open_port() {  
  kubectl port-forward -n "$2" "svc/$3" "$4:$5" >/tmp/pf-$1.log 2>&1 &
  pid=$!; sleep 1
  if kill -0 "$pid" 2>/dev/null; then
    echo "$pid $1" >> "$PID_FILE"; ok "$1 -> localhost:$4"
  else
    warn "$1 failed: $(tail -1 /tmp/pf-$1.log 2>/dev/null)"
  fi
}

forward_stop() {
  [ -f "$PID_FILE" ] || { say "nothing running"; return 0; }
  while read -r pid label; do kill "$pid" 2>/dev/null && say "stopped $label" || true; done < "$PID_FILE"
  rm -f "$PID_FILE"
}

forward_start() {
  need kubectl
  forward_stop

  bsvc=$(kubectl get svc -n "$NAMESPACE" --no-headers | awk '/backend/{print $1; exit}')
  [ -n "$bsvc" ] || die "no backend service in $NAMESPACE"
  bport=$(kubectl get svc "$bsvc" -n "$NAMESPACE" -o jsonpath='{.spec.ports[0].port}')
  open_port backend "$NAMESPACE" "$bsvc" 8001 "$bport"

  open_port argocd "$ARGOCD_NS" argocd-server 8080 443

  # Grafana and Prometheus
  gsvc=$(kubectl get svc -n "$MONITORING_NS" --no-headers 2>/dev/null | awk '/grafana/{print $1; exit}')
  [ -n "$gsvc" ] && open_port grafana "$MONITORING_NS" "$gsvc" 3000 80 \
                 || warn "grafana: not found in $MONITORING_NS"

  psvc=$(kubectl get svc -n "$MONITORING_NS" --no-headers 2>/dev/null | awk '/prometheus/{print $1; exit}')
  [ -n "$psvc" ] && open_port prometheus "$MONITORING_NS" "$psvc" 9090 9090 \
                 || warn "prometheus: not found in $MONITORING_NS"

  echo
  echo "  backend    http://localhost:8001/docs"
  echo "  ArgoCD     https://localhost:8080"
  echo "  Grafana    http://localhost:3000"
  echo "  Prometheus http://localhost:9090"
  pw=$(kubectl -n "$ARGOCD_NS" get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d || true)
  [ -n "$pw" ] && echo "  ArgoCD login: admin / $pw"
}

# update 
pull_image() {  
  image="$1"; manifest="$2"
  base="${image##*/}"
  [ -f "$manifest" ] || { warn "skipping $image ($manifest missing)"; return 0; }
  grep -Eq "image:[[:space:]]*[^[:space:]]*$base" "$manifest" || die "no image: line for $base in $manifest"

  say "Pulling $image:$TAG"
  docker pull "$image:$TAG"
  ref=$(docker inspect --format '{{index .RepoDigests 0}}' "$image:$TAG" 2>/dev/null || true)
  [ -n "$ref" ] || die "no digest for $image:$TAG. Was it pushed to Docker Hub?"

  say "Writing $ref into $manifest"
  sed -i -E "s#(image:[[:space:]]*)[^[:space:]]*$base[^[:space:]]*#\1$ref#" "$manifest"
  sed -i 's/imagePullPolicy: Never/imagePullPolicy: IfNotPresent/' "$manifest"
  grep "image:" "$manifest"
}

cmd_update() {
  TAG="${1:-latest}"
  need docker git kubectl sed
  [ "$DOCKERHUB_USER" != "YOUR_DOCKERHUB_USER" ] || die "set DOCKERHUB_USER in scripts/config.sh"
  pull_image "$BACKEND_IMAGE" "$BACKEND_MANIFEST"
  pull_image "$FRONTEND_IMAGE" "$FRONTEND_MANIFEST"
  cmd_deploy "chore: update images to $TAG"
}

# deploy
cmd_deploy() {
  need git kubectl
  branch=$(git rev-parse --abbrev-ref HEAD)
  [ "$branch" = "$GIT_BRANCH" ] || die "on '$branch', ArgoCD watches '$GIT_BRANCH'. Run: git checkout $GIT_BRANCH"

  message="${1:-chore: update k8s manifests}"
  if [ -n "$(git status --porcelain k8s)" ]; then
    say "Committing k8s/: $message"; git add k8s; git commit -m "$message"
  else
    say "Nothing new in k8s/ to commit"
  fi

  say "Pushing to origin/$GIT_BRANCH"
  git push origin "$GIT_BRANCH"
  commit=$(git rev-parse HEAD)

  say "Asking ArgoCD to refresh"
  kubectl annotate application "$ARGOCD_APP" -n "$ARGOCD_NS" argocd.argoproj.io/refresh=hard --overwrite >/dev/null

  say "Waiting for ArgoCD to sync ${commit:0:7}"
  for i in $(seq 1 60); do
    rev=$(kubectl get application "$ARGOCD_APP" -n "$ARGOCD_NS" -o jsonpath='{.status.sync.revision}' || true)
    st=$(kubectl get application "$ARGOCD_APP" -n "$ARGOCD_NS" -o jsonpath='{.status.sync.status}' || true)
    [ "$rev" = "$commit" ] && [ "$st" = Synced ] && break
    sleep 3
  done
  [ "$rev" = "$commit" ] && [ "$st" = Synced ] \
    || die "ArgoCD did not sync. Look at: kubectl describe application $ARGOCD_APP -n $ARGOCD_NS"
  ok "ArgoCD Synced"

  say "Waiting for pods"
  kubectl rollout status "deployment/$BACKEND_DEPLOY" -n "$NAMESPACE" --timeout=180s
  if kubectl get "deployment/$FRONTEND_DEPLOY" -n "$NAMESPACE" >/dev/null 2>&1; then
    kubectl rollout status "deployment/$FRONTEND_DEPLOY" -n "$NAMESPACE" --timeout=180s
  fi
  kubectl get pods -n "$NAMESPACE"
  ok "Deploy finished"
}

# check 
cmd_check() {
  need kubectl curl python3
  problems=0

  sync=$(kubectl get app "$ARGOCD_APP" -n "$ARGOCD_NS" -o jsonpath='{.status.sync.status}' 2>/dev/null || true)
  health=$(kubectl get app "$ARGOCD_APP" -n "$ARGOCD_NS" -o jsonpath='{.status.health.status}' 2>/dev/null || true)
  [ "$sync" = Synced ]   && ok "ArgoCD sync: Synced"     || { bad "ArgoCD sync: ${sync:-unknown}";     problems=$((problems+1)); }
  [ "$health" = Healthy ] && ok "ArgoCD health: Healthy" || { bad "ArgoCD health: ${health:-unknown}"; problems=$((problems+1)); }

  odd=$(kubectl get pods -n "$NAMESPACE" --no-headers | grep -v -E "Running|Completed" || true)
  [ -z "$odd" ] && ok "all pods Running" || { bad "problem pods:"; echo "$odd"; problems=$((problems+1)); }

  rdy=$(kubectl get deploy "$BACKEND_DEPLOY" -n "$NAMESPACE" -o jsonpath='{.status.readyReplicas}' || true)
  want=$(kubectl get deploy "$BACKEND_DEPLOY" -n "$NAMESPACE" -o jsonpath='{.spec.replicas}' || true)
  [ "${rdy:-0}" = "$want" ] && ok "backend replicas: ${rdy:-0}/$want" \
                            || { bad "backend replicas: ${rdy:-0}/$want"; problems=$((problems+1)); }

  unbound=$(kubectl get pvc -n "$NAMESPACE" --no-headers | grep -v Bound || true)
  [ -z "$unbound" ] && ok "all volumes Bound" || { bad "volumes: $unbound"; problems=$((problems+1)); }

  if [ "$(http "$BACKEND_URL/health")" != 200 ]; then
    bad "/health not 200. Run: ./scripts/faraja.sh forward"
    problems=$((problems+1))
  else
    ok "/health answers 200"
    echo "  what        api / db / gauge"
    echo "  projects:   $(count projects) / $(rows project) / $(gauge faraja_projects_total)"
    echo "  milestones: $(count milestones) / $(rows milestone) / $(gauge faraja_milestones_total)"
  fi

  echo
  if [ "$problems" -eq 0 ]; then ok "health check passed"
  else bad "$problems check(s) failed"; return 1; fi
}

# load 
cmd_load() {
  need curl seq xargs; ready
  rounds="${1:-100}"; burst="${BURST:-3000}"
  say "light: $rounds rounds"
  for i in $(seq 1 "$rounds"); do
    curl -s -o /dev/null "$BACKEND_URL/projects"
    curl -s -o /dev/null "$BACKEND_URL/milestones"
    curl -s -o /dev/null "$BACKEND_URL/projects/99999"
    sleep 0.1
  done
  say "burst: $burst requests, 20 parallel"
  seq 1 "$burst" | xargs -P 20 -I{} curl -s -o /dev/null --max-time 10 "$BACKEND_URL/projects"
  ok "done - Grafana: Last 15 minutes"
}

# errors 
cmd_errors() {
  need kubectl curl; ready
  ask "Stop the DB for a minute?" || return 0

  auto=$(kubectl get app "$ARGOCD_APP" -n "$ARGOCD_NS" -o jsonpath='{.spec.syncPolicy.automated}')
  [ -n "$auto" ] && kubectl patch app "$ARGOCD_APP" -n "$ARGOCD_NS" --type merge \
    -p '{"spec":{"syncPolicy":{"automated":null}}}' >/dev/null

  restore() {
    trap - EXIT INT TERM
    kubectl scale sts "$DB_STATEFULSET" -n "$NAMESPACE" --replicas=1 >/dev/null
    if [ -n "$auto" ]; then
      kubectl patch app "$ARGOCD_APP" -n "$ARGOCD_NS" --type merge \
        -p "{\"spec\":{\"syncPolicy\":{\"automated\":$auto}}}" >/dev/null
    fi
    return 0
  }
  trap restore EXIT
  trap 'restore; exit 130' INT TERM

  kubectl scale sts "$DB_STATEFULSET" -n "$NAMESPACE" --replicas=0 >/dev/null
  kubectl wait --for=delete "pod/$DB_POD" -n "$NAMESPACE" --timeout=90s 2>/dev/null || true

  say "hammering while DB down"
  errors=0
  for i in $(seq 1 "${ERROR_ROUNDS:-120}"); do
    case "$(http "$BACKEND_URL/projects")" in 5*) errors=$((errors+1));; esac
    sleep 0.3
  done
  ok "$errors 5xx"
  restore
  trap - EXIT INT TERM
  ok "done - Error Rate panel should spike"
}

# backup 
cmd_backup() {
  need kubectl
  mkdir -p backups
  f="backups/$DB_NAME-$(date +%Y%m%d-%H%M%S).sql"
  say "dumping $DB_NAME from $DB_POD"
  kubectl exec -n "$NAMESPACE" "$DB_POD" -- pg_dump -U "$DB_USER" -d "$DB_NAME" \
    --clean --if-exists --no-owner > "$f" \
    || { rm -f "$f"; die "pg_dump failed. Is the DB pod running? kubectl get pods -n $NAMESPACE"; }
  grep -q "PostgreSQL database dump complete" "$f" \
    || { rm -f "$f"; die "dump incomplete (deleted)"; }
  ok "saved $f ($(du -h "$f" | cut -f1))"
}

# rollback 
cmd_rollback() {
  need git kubectl
  branch=$(git rev-parse --abbrev-ref HEAD)
  [ "$branch" = "$GIT_BRANCH" ] || die "on '$branch'. Run: git checkout $GIT_BRANCH"
  [ -z "$(git status --porcelain --untracked-files=no)" ] || die "uncommitted changes. Commit or stash first"

  commit=$(git log -1 --format=%H -- k8s)
  [ -n "$commit" ] || die "no commit changed k8s/"
  say "Will undo:"; git log -1 --format='  %h  %s  (%an, %ar)' "$commit"
  git show --stat --format= "$commit" -- k8s | sed 's/^/  /'
  ask "Undo it and push to $GIT_BRANCH?" || return 0

  parents=$(git rev-list --parents -n 1 "$commit" | wc -w)
  [ "$parents" -gt 2 ] && merge_flag="-m 1" || merge_flag=""
  git revert --no-edit $merge_flag "$commit" || die "revert failed. Fix conflicts or: git revert --abort"
  cmd_deploy
}
# dispatch 

# forward: start/stop the port-forwards
cmd_forward() {
  case "${2:-start}" in
    start) forward_start ;;
    stop)  forward_stop  ;;
    *)     die "forward [start|stop]" ;;
  esac
}

case "${1:-help}" in
  forward) cmd_forward "$@" ;;
  check)   cmd_check ;;
  load)    shift; cmd_load "$@" ;;
  errors)  cmd_errors ;;
  backup)  cmd_backup ;;
  *)       sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' ;;
esac