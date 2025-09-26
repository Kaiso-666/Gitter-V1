out() {
    bgcolor="\e[48;2;28;29;35m"
    reset="\e[0m"
    clear
    echo -e "$bgcolor$1$reset"
}
out "
   _____ _ _   _             __      ____ 
  / ____(_) | | |            \ \    / /_ |
 | |  __ _| |_| |_ ___ _ __   \ \  / / | |
 | | |_ | | __| __/ _ \ '__|   \ \/ /  | |
 | |__| | | |_| ||  __/ |       \  /   | |
  \_____|_|\__|\__\___|_| _      \/    |_|
 |  _ \        | |/ /    (_)              
 | |_) |_   _  | ' / __ _ _ ___  ___      
 |  _ <| | | | |  < / _\` | / __|/ _ \     
 | |_) | |_| | | . \ (_| | \__ \ (_) |    
 |____/ \__, | |_|\_\__,_|_|___/\___/     
         __/ |                            
        |___/                             
"
read
out "Updating Package List"
pkg update -y
out "Would you like to upgrade current packages? (This may involve large downloads depending on the number of packages.) [y/N]"
read -r up_choice
if [ "$up_choice" = "y" ] || [ "$up_choice" = "Y" ]; then
    pkg upgrade -y
else
    out "Upgrade skipped."
fi
out "Installing Required Packages"
pkg install git openssh gh -y
out "Any questions asked after this point WILL NOT BE SAVED UPLOADED OR LEAK IN ANY WAY."
out "Enter Your Name: "
read name
git config --global user.name $name
out "Enter Your Email Address: "
read email
git config --global user.email $email
git config --global init.defaultBranch main

cat > /data/data/com.termux/files/usr/bin/gitter <<'EOF'
#!/usr/bin/env bash
set -e

usage(){
  cat <<EOF2
Usage:
  gitter newdir <dir>
  gitter newrepo [owner/]repo [--private|--public]
  gitter enable
  gitter up [commit-message]
  gitter list
  gitter delete <owner/repo>
EOF2
  exit 1
}

newdir(){
  dir="$1"
  [ -z "$dir" ] && { echo "specify directory"; exit 1; }
  mkdir -p "$dir"
  cd "$dir"
  git init
  git config init.defaultBranch main
  [ ! -f README.md ] && echo "# $(basename "$dir")" > README.md
  [ ! -f .gitignore ] && printf "node_modules/\n.DS_Store\n" > .gitignore
  git add .
  git commit -m "initial commit" || true
  echo "directory ready: $dir"
}

newrepo(){
  repo_arg="$1"
  privacy="public"
  for a in "$@"; do
    case "$a" in
      --private) privacy="private";;
      --public) privacy="public";;
    esac
  done

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git init
    git config init.defaultBranch main
    [ ! -f README.md ] && echo "# $(basename "$(pwd)")" > README.md
    git add .
    git commit -m "initial commit" || true
  fi

  repo_name="${repo_arg:-$(basename "$(pwd)")}"
  if [[ "$repo_name" == */* ]]; then
    full_name="$repo_name"
  else
    if command -v gh >/dev/null 2>&1; then
      user=$(gh api user --jq .login)
      full_name="$user/$repo_name"
    else
      full_name="$repo_name"
    fi
  fi

  gh repo create "$full_name" --"$privacy" --source=. --remote=origin --push --confirm
  echo "Repo created and pushed: $full_name"
}

enable(){
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "already a git repo"
  else
    git init
    git config init.defaultBranch main
    echo "initialized git repo in $(pwd)"
  fi

  [ ! -f README.md ] && echo "# $(basename "$(pwd)")" > README.md
  [ ! -f .gitignore ] && printf "node_modules/\n.DS_Store\n" > .gitignore

  if git rev-parse --verify HEAD >/dev/null 2>&1; then
    echo "repo has commits"
  else
    git add .
    git commit -m "initial commit" || true
    echo "initial commit created"
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    echo "remote origin exists: $(git remote get-url origin)"
  else
    echo "no remote 'origin' configured. run: gitter newrepo or add remote manually"
  fi
}

up(){
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "not a git repo. auto-enabling git in this directory."
    enable
  fi

  if [ -n "$(git status --porcelain)" ]; then
    msg="${1:-update: $(date +%Y-%m-%d_%H-%M)}"
    git add .
    git commit -m "$msg"
  else
    echo "no changes to commit"
  fi

  if git remote get-url origin >/dev/null 2>&1; then
    branch=$(git rev-parse --abbrev-ref HEAD || echo main)
    git pull --rebase origin "$branch" || true
    git push -u origin "$branch" || git push
    echo "pushed"
  else
    echo "no remote 'origin' configured. run: gitter newrepo to create and push to GitHub"
    exit 1
  fi
}

list(){
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found, install it first."
    exit 1
  fi
  gh repo list --limit 100
}

delete(){
  repo="$1"
  [ -z "$repo" ] && { echo "specify repo to delete: owner/repo"; exit 1; }
  if ! command -v gh >/dev/null 2>&1; then
    echo "gh CLI not found, install it first."
    exit 1
  fi
  gh repo delete "$repo" --confirm
  echo "Deleted repo: $repo"
}

[ $# -lt 1 ] && usage
cmd="$1"; shift
case "$cmd" in
  newdir) newdir "$@";;
  newrepo) newrepo "$@";;
  enable) enable "$@";;
  up) up "$@";;
  list) list "$@";;
  delete) delete "$@";;
  -h|--help|help) usage;;
  *) usage;;
esac
EOF

chmod +x /data/data/com.termux/files/usr/bin/gitter

out "Initialization Complete."
read
out "Login To GitHub"
read
out "Recommended Steps:
1. Select GitHub.com
2. HTTPS
3. Login with a web browser
"

gh auth login

out "Setup Complete.
Use cmd \"gitter newdir\" to make a new directory ready for GitHub.
Use cmd \"gitter newrepo\" to make a new repository.
Use cmd \"gitter enable\" to enable GitHub support of normal directory.
Use cmd \"gitter up\" to update your repo with you current device copy.
"