#!/usr/bin/env bash
# GitHub Pages 部署脚本
# 用法：把下面两个变量改成你自己的，然后 bash deploy.sh
set -euo pipefail

# ==== 改这两行 ====
GH_USER="${GH_USER:-你的GitHub用户名}"       # 例如：octocat
GH_REPO="${GH_REPO:-url-prefix-replacer}"    # 仓库名，先跟这个也行
# ==================

# 颜色/符号
if command -v tput >/dev/null 2>&1 && [ -t 1 ]; then
  BOLD="$(tput bold)"; DIM="$(tput dim)"; RED="$(tput setaf 1)"; GREEN="$(tput setaf 2)"; YELLOW="$(tput setaf 3)"; BLUE="$(tput setaf 4)"; RESET="$(tput sgr0)"
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

info() { printf '%s\n' "${BLUE}==>${RESET} $*"; }
ok()   { printf '%s\n' "${GREEN} ✔ ${RESET}$*"; }
warn() { printf '%s\n' "${YELLOW} ⚠ ${RESET}$*"; }
err()  { printf '%s\n' "${RED} ✖ ${RESET}$*" >&2; }
step() { printf '\n%s\n' "${BOLD}── $* ──${RESET}"; }

cd "$(dirname "$0")"

# 0. 前置检查
step "0/5 前置检查"
if [ "$GH_USER" = "你的GitHub用户名" ]; then
  err "请先编辑 deploy.sh，把 GH_USER 改成你自己的 GitHub 用户名（登录 github.com 后右上角头像旁边的名字）"
  exit 2
fi
command -v git >/dev/null || { err "找不到 git，请先装 git"; exit 3; }
ok "git $(git --version | awk '{print $3}')"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  info "当前目录不是 git 仓库，正在初始化"
  git init -b main
  git add .
  git -c user.name="${GH_USER}" -c user.email="${GH_USER}@users.noreply.github.com" commit -m "chore: initial commit" || warn "无变更可提交，继续"
else
  ok "已是 git 仓库，分支：$(git rev-parse --abbrev-ref HEAD)"
fi
# 确保 index.html 在根目录（GitHub Pages 默认从根目录构建）
if [ ! -f index.html ]; then
  err "根目录没有 index.html，GitHub Pages 会 404。请先把 index.html 放到仓库根目录"
  exit 4
fi
ok "index.html 已在根目录"

# 1. 检查 gh CLI（可选，装了就能一键开启 Pages）
step "1/5 检查 gh CLI"
HAS_GH=0
if command -v gh >/dev/null 2>&1; then
  HAS_GH=1
  ok "gh $(gh --version | head -1)"
  if gh auth status >/dev/null 2>&1; then
    ok "gh 已登录：$(gh api user --jq .login 2>/dev/null || echo '(无法读取用户名)')"
  else
    warn "gh 未登录，稍后可执行：gh auth login"
  fi
else
  warn "未装 gh CLI（可选）。装了能一键开启 Pages；不装就去网页 Settings 里点开"
  info "macOS 装法：brew install gh"
fi

# 2. 确保有 GitHub 远端仓库（用户需先在 github.com 网页上 New repository 建一个空仓库）
step "2/5 配置远端仓库"
if git remote get-url origin >/dev/null 2>&1; then
  CUR_URL="$(git remote get-url origin)"
  info "已有 origin：$CUR_URL"
  read -r -p "${DIM}使用这个 origin 吗？[Y/n] ${RESET}" ans </dev/tty || ans="Y"
  case "${ans:-Y}" in
    [Yy]*|"") ok "沿用现有 origin" ;;
    *)
      read -r -p "${DIM}新的仓库名（回车默认 ${GH_REPO}）：${RESET}" NEW_REPO </dev/tty || NEW_REPO="$GH_REPO"
      NEW_REPO="${NEW_REPO:-$GH_REPO}"
      git remote set-url origin "git@github.com:${GH_USER}/${NEW_REPO}.git"
      ok "origin 已改为：$(git remote get-url origin)"
      ;;
  esac
else
  read -r -p "${DIM}远端协议 [ssh|https]（回车默认 ssh）：${RESET}" PROTO </dev/tty || PROTO="ssh"
  PROTO="${PROTO:-ssh}"
  if [ "$PROTO" = "https" ]; then
    read -r -s -p "${DIM}GitHub Personal Access Token（要有 repo 权限；输入时不回显）：${RESET}" GH_TOKEN </dev/tty || GH_TOKEN=""
    echo
    if [ -z "$GH_TOKEN" ]; then
      err "HTTPS 方式需要 PAT。不想给 PAT 就改用 ssh（在本机配好 SSH key 后上传到 GitHub）"
      exit 5
    fi
    git remote add origin "https://${GH_USER}:${GH_TOKEN}@github.com/${GH_USER}/${GH_REPO}.git"
    warn "已把 PAT 写进 remote URL。请注意别把这份仓库公开，否则会泄露 token"
  else
    git remote add origin "git@github.com:${GH_USER}/${GH_REPO}.git"
  fi
  ok "origin 已添加：$(git remote get-url origin | sed -E 's#//[^@]*@#//***:***@#')"
fi

# 3. push
step "3/5 推送到 GitHub"
info "远端：$(git remote get-url origin | sed -E 's#//[^@]*@#//***:***@#')"
info "如提示认证失败："
info "  · ssh 方式：确认 ~/.ssh/id_ed25519.pub（或 id_rsa.pub）已加到 GitHub → Settings → SSH and GPG keys"
info "  · https 方式：确认 PAT 有 repo 权限，且未过期"
if git push -u origin main; then
  ok "push 成功"
else
  err "push 失败。请根据上面的提示排查认证后重试：git push -u origin main"
  exit 6
fi

# 4. 开启 GitHub Pages
step "4/5 开启 GitHub Pages"
if [ "$HAS_GH" = "1" ] && gh auth status >/dev/null 2>&1; then
  info "调用 API 开启 Pages（source=main 分支，路径=/）"
  # 用 legacy Pages 端点（source: legacy 表示从根目录构建）
  if gh api -X POST -H "Accept: application/vnd.github+json" \
      "/repos/${GH_USER}/${GH_REPO}/pages" \
      -f "source=main" -f "legacy_build=true" >/dev/null 2>&1; then
    ok "Pages 已开启（首次创建）"
  elif gh api -X PUT -H "Accept: application/vnd.github+json" \
      "/repos/${GH_USER}/${GH_REPO}/pages" \
      -f "source=main" -f "legacy_build=true" >/dev/null 2>&1; then
    ok "Pages 已更新"
  else
    warn "API 开启失败（可能仓库不存在或权限不足）。请到网页手动开启："
    info "  https://github.com/${GH_USER}/${GH_REPO}/settings/pages"
    info "  Build and deployment → Source: Deploy from a branch → main → Save"
  fi
  # 查询构建状态
  sleep 3
  STATUS_URL="https://github.com/${GH_USER}/${GH_REPO}/deployments/activity_log/checks_uri=public_repo"
  info "查看构建日志：${STATUS_URL}"
else
  warn "未装 gh CLI 或未登录，请手动开启 Pages："
  info "  1. 打开 https://github.com/${GH_USER}/${GH_REPO}/settings/pages"
  info "  2. Build and deployment → Source: ${BOLD}Deploy from a branch${RESET} → Branch: ${BOLD}main${RESET} → Save"
fi

# 5. 输出访问地址
step "5/5 完成"
SITE_URL="https://${GH_USER}.github.io/${GH_REPO}/"
printf '\n%s\n' "${BOLD}${GREEN}公开访问地址：${RESET} ${SITE_URL}${RESET}"
printf '%s\n' "${DIM}（GitHub Pages 首次构建约需 1 分钟；打不开就等一会再刷新，或去仓库 Actions 页看构建日志）${RESET}"
printf '\n%s\n' "${BOLD}下一步建议${RESET}"
printf '%s\n' "  · 打开 ${SITE_URL} 试用：粘贴一个 https://www.skyvendorise.com/... 的 URL"
printf '%s\n' "  · 以后想改规则，编辑 index.html 顶部的 SOURCE / TARGET 两个常量后重新 push"
printf '%s\n' "  · 仓库设为 Public，任何人访问 ${SITE_URL} 都能用"
