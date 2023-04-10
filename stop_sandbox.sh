set -e
docker stop mlgl_sandbox >/dev/null 2>&1 || true && docker rm mlgl_sandbox >/dev/null 2>&1 || true
