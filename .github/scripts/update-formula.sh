#!/bin/bash
set -euo pipefail

VERSION="$1"
ZIP_URL="$2"

cat <<EOF
cask "present" do
  version "$VERSION"
  sha256 "$SHA256"

  url "$ZIP_URL"
  name "Present"
  desc "macOS presentation app for displaying web-based slideshows"
  homepage "https://github.com/btbytes/present"

  depends_on arch: :arm64
  depends_on macos: :sonoma

  app "Present.app"
end
EOF
